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

    // --- Post a want through the FAB sheet. ---
    await _tap(tester, find.widgetWithText(FloatingActionButton, 'Post a want'));
    await _pumpUntil(tester, find.widgetWithText(TextField, 'Item'));

    final wantTitle = 'IT Sneakers $stamp';
    await tester.enterText(
        find.widgetWithText(TextField, 'Item'), wantTitle);
    await tester.enterText(find.widgetWithText(TextField, 'Details'),
        'Integration-test want, safe to ignore.');
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
}
