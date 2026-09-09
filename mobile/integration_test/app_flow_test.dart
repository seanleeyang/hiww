// End-to-end flow against a REAL running backend.
//
//   Terminal 1:  cd ..  &&  npm run db:setup  &&  npm run dev
//   Terminal 2:  flutter test integration_test/app_flow_test.dart
//
// Runs on the flutter-tester VM (no device/chromedriver needed): the real
// widget tree, real go_router, real Dio over dart:io sockets. Only the token
// store is faked (the secure-storage plugin has no VM implementation).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:hiww_mobile/app.dart';
import 'package:hiww_mobile/core/api/api_client.dart';
import 'package:hiww_mobile/core/storage/token_storage.dart';
import 'package:hiww_mobile/ui/soft_card.dart';

const _baseUrl = 'http://localhost:3000';

class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage([this._token]) : super(const FlutterSecureStorage());
  String? _token;
  @override
  Future<String?> read() async => _token;
  @override
  Future<void> write(String token) async => _token = token;
  @override
  Future<void> clear() async => _token = null;
}

List<Override> _appOverrides([String? token]) => [
      tokenStorageProvider.overrideWithValue(_MemoryTokenStorage(token)),
      apiClientProvider.overrideWith(
        (ref) => ApiClient(
          baseUrl: _baseUrl,
          tokenStorage: ref.watch(tokenStorageProvider),
        ),
      ),
    ];

Future<Map<String, dynamic>> _register(String kind, int stamp,
    {required String type}) {
  return _api('POST', '/api/auth/register', body: {
    'email': 'it-$kind-$stamp@example.com',
    'full_name': '${kind[0].toUpperCase()}${kind.substring(1)} Tester',
    'user_type': type,
    'password': 'SecurePass123!',
  });
}

const _adminEmail = 'it-admin@example.com';
const _adminPass = 'AdminPass123';

/// Returns an admin bearer token. Logs in if the account exists, otherwise runs
/// the repo's idempotent `create-admin` script (needs the API's working tree).
Future<String> _adminToken() async {
  try {
    final r = await _api('POST', '/api/auth/login',
        body: {'email': _adminEmail, 'password': _adminPass});
    return r['token'] as String;
  } catch (_) {
    final res = await Process.run(
      'npx',
      ['tsx', 'scripts/create-admin.ts', _adminEmail, _adminPass],
      workingDirectory: Directory.current.parent.path,
      runInShell: true,
    );
    if (res.exitCode != 0) {
      fail('Could not create the test admin. Run once:\n'
          '  cd ..  &&  npm run create-admin $_adminEmail $_adminPass\n'
          '${res.stdout}\n${res.stderr}');
    }
    final r = await _api('POST', '/api/auth/login',
        body: {'email': _adminEmail, 'password': _adminPass});
    return r['token'] as String;
  }
}

String _isoDays(int n) =>
    DateTime.now().toUtc().add(Duration(days: n)).toIso8601String();

/// Bare HTTP helper for seeding data and the health probe.
Future<Map<String, dynamic>> _api(
  String method,
  String path, {
  String? token,
  Map<String, dynamic>? body,
}) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl(method, Uri.parse('$_baseUrl$path'));
    if (token != null) req.headers.set('authorization', 'Bearer $token');
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 400) {
      throw HttpException('$method $path -> ${res.statusCode}: $text');
    }
    final decoded = text.isEmpty ? const {} : jsonDecode(text);
    if (decoded is Map && decoded['data'] is Map) {
      return (decoded['data'] as Map).cast<String, dynamic>();
    }
    return (decoded as Map).cast<String, dynamic>();
  } finally {
    client.close(force: true);
  }
}

/// [WidgetTester.pumpAndSettle] can't be used here — the app keeps a
/// [CircularProgressIndicator] and 5–15s polling timers alive, so it never
/// "settles". Pump in small steps until [finder] hits or we give up.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  final visible = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .toList();
  throw TestFailure(
      'Timed out after $timeout waiting for: $finder\nVisible text: $visible');
}

/// A [FilledButton] whose label contains [text] (labels carry a trailing price).
Finder _button(String text) => find.ancestor(
      of: find.textContaining(text),
      matching: find.byType(FilledButton),
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  try {
    await tester.ensureVisible(finder);
  } catch (_) {
    // Not inside a Scrollable (e.g. a dialog button) — fine.
  }
  await tester.pump();
  await tester.tap(finder.first, warnIfMissed: false);
  // Let any resulting navigation / network settle a little.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      await _api('GET', '/health');
    } catch (e) {
      fail(
        'The Hiww API must be running on $_baseUrl for this test.\n'
        '  cd ..  &&  npm run db:setup  &&  npm run dev\n'
        'Original error: $e',
      );
    }
  });

  testWidgets('register → see a seeded trip on Browse → post a want', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final stamp = DateTime.now().millisecondsSinceEpoch;

    // --- Seed: a traveler with a published Bangkok → Tokyo trip. ---
    final traveler = await _register('traveler', stamp, type: 'traveler');
    await _api('POST', '/api/trips', token: traveler['token'] as String, body: {
      'departure_country': 'TH',
      'arrival_country': 'JP',
      'departure_city': 'Bangkok',
      'arrival_city': 'Tokyo',
      'departure_date':
          DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
      'return_date':
          DateTime.now().toUtc().add(const Duration(days: 21)).toIso8601String(),
      'max_weight_kg': 8,
      'max_items': 5,
    });

    // --- Boot the real app with a fresh (empty) session. ---
    await tester.pumpWidget(
      ProviderScope(overrides: _appOverrides(), child: const HiwwApp()),
    );

    // Cold start, no token → login screen.
    await _pumpUntil(tester, find.text('Welcome back'));

    // --- Register a shopper through the UI. ---
    await _tap(tester, find.widgetWithText(TextButton, 'Create an account'));
    await _pumpUntil(tester, find.text('Create your account'));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'), 'Sam Shopper');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'),
        'it-shopper-$stamp@example.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'SecurePass123!');
    await _tap(tester, find.text('Shop')); // user_type: shopper
    await _tap(tester, find.widgetWithText(FilledButton, 'Create account'));

    // Real register + /api/me + feed load → the Browse feed with the seed trip.
    await _pumpUntil(tester, find.textContaining('Bangkok → Tokyo'),
        timeout: const Duration(seconds: 40));

    // --- Post a want through the Create Order sheet → Summary flow. ---
    // Travel is the default tab; the want-creation FAB only shows on Order.
    // NOTE: a photo, Buy-in country/city, and Deliver-to country/city are all
    // now required fields, and there's no real gallery/file picker on the
    // headless flutter-tester VM this suite runs on — so this scenario can't
    // currently drive all the way to "Next" without a dedicated test seam
    // for ImagePickerField. Left in place (rather than stubbed to a false
    // pass) so the gap stays visible; it will fail at the "Next" tap
    // (missing photo) until that seam exists.
    await _tap(tester, find.widgetWithText(Tab, 'Order'));
    await _tap(tester, find.byType(FloatingActionButton));
    await _pumpUntil(tester, find.widgetWithText(TextField, 'Product Name'));

    final wantTitle = 'IT Sneakers $stamp';
    await tester.enterText(
        find.widgetWithText(TextField, 'Product Name'), wantTitle);
    await tester.enterText(find.widgetWithText(TextField, 'Product Details'),
        'Integration-test want, safe to ignore.');
    await _tap(tester, find.widgetWithText(FilledButton, 'Next'));
    await _pumpUntil(tester, find.text('Summary'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Post my want'));

    // Submit → navigates to /wants/:id → detail screen shows the title.
    await _pumpUntil(tester, find.text(wantTitle),
        timeout: const Duration(seconds: 40));

    // And it is now the caller's want.
    final shopperToken = (await _api('POST', '/api/auth/login', body: {
      'email': 'it-shopper-$stamp@example.com',
      'password': 'SecurePass123!',
    }))['token'] as String;
    final mine = await _api('GET', '/api/requests/mine', token: shopperToken);
    expect(
      (mine['items'] as List).any((w) => (w as Map)['title'] == wantTitle),
      isTrue,
      reason: 'the new want should appear in /api/requests/mine',
    );
  });

  testWidgets('shopper opens a want, accepts an offer, reports payment',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final stamp = DateTime.now().millisecondsSinceEpoch;

    // --- Seed a want with one pending offer on it. ---
    final shopper = await _register('shopper', stamp, type: 'shopper');
    final traveler = await _register('traveler', stamp, type: 'traveler');
    final shopperToken = shopper['token'] as String;
    final travelerToken = traveler['token'] as String;

    final wantTitle = 'IT Camera $stamp';
    final want = await _api('POST', '/api/requests',
        token: shopperToken,
        body: {
          'title': wantTitle,
          'item_description': 'Mirrorless body, boxed, from any Tokyo store.',
          'source_country': 'JP',
          'category': 'other',
          'estimated_weight_kg': 1.0,
          'budget': '25000.00',
        });
    final trip = await _api('POST', '/api/trips', token: travelerToken, body: {
      'departure_country': 'TH',
      'arrival_country': 'JP',
      'departure_date':
          DateTime.now().toUtc().add(const Duration(days: 5)).toIso8601String(),
      'return_date':
          DateTime.now().toUtc().add(const Duration(days: 15)).toIso8601String(),
      'max_weight_kg': 6,
      'max_items': 3,
    });
    await _api('POST', '/api/offers', token: travelerToken, body: {
      'request_id': want['id'],
      'trip_id': trip['id'],
      'quoted_price': '24000.00',
      'delivery_date':
          DateTime.now().toUtc().add(const Duration(days: 12)).toIso8601String(),
    });

    // --- Boot straight into the signed-in shopper session. ---
    await tester.pumpWidget(
      ProviderScope(
        overrides: _appOverrides(shopperToken),
        child: const HiwwApp(),
      ),
    );

    // My Wants tab → the want → its offers.
    await _pumpUntil(tester, find.text('My Wants'),
        timeout: const Duration(seconds: 40));
    await _tap(tester, find.text('My Wants'));
    await _pumpUntil(tester, find.textContaining(wantTitle));
    await _tap(tester, find.textContaining(wantTitle));

    await _pumpUntil(tester, find.widgetWithText(FilledButton, 'Accept offer'),
        timeout: const Duration(seconds: 30));
    await _tap(tester, find.widgetWithText(FilledButton, 'Accept offer'));

    // Confirmation dialog.
    await _pumpUntil(tester, find.text('Accept this offer?'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Accept'));

    // Lands on the order screen, awaiting payment.
    await _pumpUntil(
        tester, find.widgetWithText(FilledButton, "I've sent the payment"),
        timeout: const Duration(seconds: 40));
    await _tap(
        tester, find.widgetWithText(FilledButton, "I've sent the payment"));

    // The order now shows the claimed-payment state.
    await _pumpUntil(tester, find.textContaining('told us you paid'),
        timeout: const Duration(seconds: 30));

    // Backend agrees: an order exists, awaiting payment, claim recorded.
    final orders = await _api('GET', '/api/orders', token: shopperToken);
    final order = (orders['items'] as List).first as Map;
    expect(order['status'], 'pending_payment');
    expect(order['payment_claimed_at'], isNotNull);
  });

  testWidgets('shopper confirms receipt and reviews an in-transit order',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final stamp = DateTime.now().millisecondsSinceEpoch;

    // --- Seed an order all the way to in_transit (needs an admin to confirm
    //     the payment during the manual-money pilot). ---
    final shopper = await _register('shopper', stamp, type: 'shopper');
    final traveler = await _register('traveler', stamp, type: 'traveler');
    final shopperToken = shopper['token'] as String;
    final travelerToken = traveler['token'] as String;

    final want = await _api('POST', '/api/requests', token: shopperToken, body: {
      'title': 'IT Headphones $stamp',
      'item_description': 'Over-ear, noise cancelling, boxed.',
      'source_country': 'JP',
      'category': 'other',
      'estimated_weight_kg': 1.0,
      'budget': '9000.00',
    });
    final trip = await _api('POST', '/api/trips', token: travelerToken, body: {
      'departure_country': 'TH',
      'arrival_country': 'JP',
      'departure_date': _isoDays(4),
      'return_date': _isoDays(14),
      'max_weight_kg': 6,
      'max_items': 3,
    });
    final offer = await _api('POST', '/api/offers', token: travelerToken, body: {
      'request_id': want['id'],
      'trip_id': trip['id'],
      'quoted_price': '8500.00',
      'delivery_date': _isoDays(11),
    });
    final accept = await _api('POST', '/api/offers/${offer['id']}/accept',
        token: shopperToken);
    final orderId = accept['order_id'] as String;
    await _api('POST', '/api/orders/$orderId/claim-payment', token: shopperToken);
    await _api('POST', '/api/payments/confirm',
        token: await _adminToken(), body: {'order_id': orderId});
    await _api('POST', '/api/orders/$orderId/deliver',
        token: travelerToken, body: {'note': 'Handed to courier'});

    // --- Shopper opens the order and confirms receipt through the UI. ---
    await tester.pumpWidget(
      ProviderScope(
        overrides: _appOverrides(shopperToken),
        child: const HiwwApp(),
      ),
    );

    await _pumpUntil(tester, find.text('My Wants'),
        timeout: const Duration(seconds: 40));
    await _tap(tester, find.text('My Wants'));
    await _pumpUntil(tester, find.textContaining('View order'),
        timeout: const Duration(seconds: 30));
    await _tap(tester, find.textContaining('View order'));

    // Order screen, in transit → the confirm-&-release action.
    await _pumpUntil(tester, _button('Confirm & release'),
        timeout: const Duration(seconds: 30));
    await _tap(tester, _button('Confirm & release'));

    // Confirm & review screen — default 5 stars, add a comment, submit.
    await _pumpUntil(tester, find.text('Confirm & review'),
        timeout: const Duration(seconds: 20));
    await tester.enterText(
        find.byType(TextField).last, 'Smooth handover, thanks!');
    await _tap(tester, _button('Confirm & release'));

    // Back on the order, now delivered + rated.
    await _pumpUntil(tester, find.textContaining('You rated'),
        timeout: const Duration(seconds: 30));

    // Backend: order delivered, review stored, traveler's delivered_count up.
    final order = await _api('GET', '/api/orders/$orderId', token: shopperToken);
    expect(order['status'], 'delivered');
    expect(order['my_review'], isNotNull);

    final reviews = await _api(
        'GET', '/api/users/${traveler['userId']}/reviews',
        token: shopperToken);
    expect((reviews['items'] as List), isNotEmpty);

    final me = await _api('GET', '/api/me', token: travelerToken);
    expect(me['delivered_count'], 1);
  });

  testWidgets('traveler opens a want and sends an offer', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final stamp = DateTime.now().millisecondsSinceEpoch;

    final traveler = await _register('traveler', stamp, type: 'traveler');
    final shopper = await _register('shopper', stamp, type: 'shopper');
    final travelerToken = traveler['token'] as String;

    // Traveler already has a published trip; shopper posts a want.
    await _api('POST', '/api/trips', token: travelerToken, body: {
      'departure_country': 'TH', 'arrival_country': 'JP',
      'departure_city': 'Bangkok', 'arrival_city': 'Tokyo',
      'departure_date': _isoDays(4), 'return_date': _isoDays(16),
      'max_weight_kg': 7, 'max_items': 4, 'title': 'Bangkok → Tokyo',
    });
    final wantTitle = 'IT Watch $stamp';
    await _api('POST', '/api/requests',
        token: shopper['token'] as String,
        body: {
          'title': wantTitle,
          'item_description': 'Casio A168, silver. Any Tokyo store is fine.',
          'source_country': 'JP', 'category': 'other',
          'estimated_weight_kg': 1.0, 'budget': '3000.00',
        });

    await tester.pumpWidget(
      ProviderScope(
          overrides: _appOverrides(travelerToken), child: const HiwwApp()),
    );

    await _pumpUntil(tester, find.textContaining(wantTitle),
        timeout: const Duration(seconds: 40));
    await _tap(tester, find.textContaining(wantTitle));

    await _pumpUntil(tester, _button('Make an offer'),
        timeout: const Duration(seconds: 30));
    await _tap(tester, _button('Make an offer'));

    // MakeOfferScreen: trip is pre-selected; set a price and a delivery date.
    await _pumpUntil(tester, find.widgetWithText(TextField, 'Your price for the goods'),
        timeout: const Duration(seconds: 20));
    await tester.enterText(
        find.widgetWithText(TextField, 'Your price for the goods'), '2800');
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Pick a date'));
    await _pumpUntil(tester, find.text('OK'));
    await _tap(tester, find.text('OK'));
    await _tap(tester, _button('Send offer'));

    // Back on the want; the offer exists.
    await _pumpUntil(tester, find.textContaining(wantTitle),
        timeout: const Duration(seconds: 30));
    final offers = await _api('GET', '/api/offers/mine', token: travelerToken);
    expect((offers['items'] as List), isNotEmpty);
  });

  testWidgets('shopper reports a problem, and it reaches the admin queue',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final stamp = DateTime.now().millisecondsSinceEpoch;

    final shopper = await _register('shopper', stamp, type: 'shopper');
    final traveler = await _register('traveler', stamp, type: 'traveler');
    final shopperToken = shopper['token'] as String;
    final travelerToken = traveler['token'] as String;

    final want = await _api('POST', '/api/requests', token: shopperToken, body: {
      'title': 'IT Kettle $stamp',
      'item_description': 'Electric kettle, 1L, from any Tokyo store.',
      'source_country': 'JP', 'category': 'other',
      'estimated_weight_kg': 1.5, 'budget': '5000.00',
    });
    final trip = await _api('POST', '/api/trips', token: travelerToken, body: {
      'departure_country': 'TH', 'arrival_country': 'JP',
      'departure_date': _isoDays(3), 'return_date': _isoDays(13),
      'max_weight_kg': 6, 'max_items': 3,
    });
    final offer = await _api('POST', '/api/offers', token: travelerToken, body: {
      'request_id': want['id'], 'trip_id': trip['id'],
      'quoted_price': '4800.00', 'delivery_date': _isoDays(10),
    });
    final accept = await _api('POST', '/api/offers/${offer['id']}/accept',
        token: shopperToken);
    final orderId = accept['order_id'] as String;

    await tester.pumpWidget(
      ProviderScope(
          overrides: _appOverrides(shopperToken), child: const HiwwApp()),
    );

    await _pumpUntil(tester, find.text('My Wants'),
        timeout: const Duration(seconds: 40));
    await _tap(tester, find.text('My Wants'));
    await _pumpUntil(tester, find.textContaining('View order'),
        timeout: const Duration(seconds: 30));
    await _tap(tester, find.textContaining('View order'));

    await _pumpUntil(tester, find.widgetWithText(OutlinedButton, 'Report'),
        timeout: const Duration(seconds: 30));
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Report'));

    await _pumpUntil(tester, find.text('Report a problem'));
    await tester.enterText(find.byType(TextField).last,
        'Two of the three items were missing from the parcel on arrival.');
    await _tap(tester, _button('Submit report'));

    await _pumpUntil(tester, find.textContaining('Reported'),
        timeout: const Duration(seconds: 30));

    final queue =
        await _api('GET', '/api/admin/reviews', token: await _adminToken());
    expect(
      (queue['queue'] as List).any(
          (e) => e['type'] == 'dispute' && e['order_id'] == orderId),
      isTrue,
      reason: 'the dispute should show in the admin review queue',
    );
  });

  testWidgets('a new user submits KYC and lands in the admin queue',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final user = await _register('kyc', stamp, type: 'both');

    await tester.pumpWidget(
      ProviderScope(
          overrides: _appOverrides(user['token'] as String),
          child: const HiwwApp()),
    );

    await _pumpUntil(tester, find.byTooltip('Account'),
        timeout: const Duration(seconds: 40));
    await _tap(tester, find.byTooltip('Account'));

    await _pumpUntil(tester, find.text('ID check'),
        timeout: const Duration(seconds: 20));
    await _tap(
        tester, find.widgetWithText(FilledButton, 'Update ID details'));
    await _pumpUntil(
        tester, find.widgetWithText(TextField, 'Document number'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Document number'), 'X1234567');
    await _tap(tester, _button('Submit for review'));

    await _pumpUntil(tester, find.textContaining('Submitted for review'),
        timeout: const Duration(seconds: 30));

    final queue =
        await _api('GET', '/api/admin/reviews', token: await _adminToken());
    expect(
      (queue['queue'] as List).any(
          (e) => e['type'] == 'kyc' && e['user_id'] == user['userId']),
      isTrue,
      reason: 'the KYC submission should show in the admin review queue',
    );
  });

  testWidgets('traveler marks a confirmed order shipped', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final stamp = DateTime.now().millisecondsSinceEpoch;

    final shopper = await _register('shopper', stamp, type: 'shopper');
    final traveler = await _register('traveler', stamp, type: 'traveler');
    final shopperToken = shopper['token'] as String;
    final travelerToken = traveler['token'] as String;

    final want = await _api('POST', '/api/requests', token: shopperToken, body: {
      'title': 'IT Charger $stamp',
      'item_description': 'USB-C 65W GaN charger, boxed.',
      'source_country': 'JP', 'category': 'other',
      'estimated_weight_kg': 0.5, 'budget': '2500.00',
    });
    final trip = await _api('POST', '/api/trips', token: travelerToken, body: {
      'departure_country': 'TH', 'arrival_country': 'JP',
      'departure_date': _isoDays(3), 'return_date': _isoDays(13),
      'max_weight_kg': 6, 'max_items': 3,
    });
    final offer = await _api('POST', '/api/offers', token: travelerToken, body: {
      'request_id': want['id'], 'trip_id': trip['id'],
      'quoted_price': '2300.00', 'delivery_date': _isoDays(10),
    });
    final accept = await _api('POST', '/api/offers/${offer['id']}/accept',
        token: shopperToken);
    final orderId = accept['order_id'] as String;
    await _api('POST', '/api/orders/$orderId/claim-payment', token: shopperToken);
    await _api('POST', '/api/payments/confirm',
        token: await _adminToken(), body: {'order_id': orderId});

    await tester.pumpWidget(
      ProviderScope(
          overrides: _appOverrides(travelerToken), child: const HiwwApp()),
    );

    // My Trips → Offers tab → the accepted offer → its order.
    await _pumpUntil(tester, find.text('My Trips'),
        timeout: const Duration(seconds: 40));
    await _tap(tester, find.text('My Trips'));
    await _pumpUntil(tester, find.text('Offers'));
    await _tap(tester, find.text('Offers'));
    // Give myOrdersProvider time to resolve so the card links to the order.
    await _pumpUntil(tester, find.byType(SoftCard),
        timeout: const Duration(seconds: 20));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await _tap(tester, find.byType(SoftCard).first);

    await _pumpUntil(tester, _button('Mark as shipped'),
        timeout: const Duration(seconds: 30));
    await _tap(tester, _button('Mark as shipped'));

    await _pumpUntil(tester, find.textContaining('Waiting for the shopper'),
        timeout: const Duration(seconds: 30));

    final order = await _api('GET', '/api/orders/$orderId', token: travelerToken);
    expect(order['status'], 'in_transit');
  });
}
