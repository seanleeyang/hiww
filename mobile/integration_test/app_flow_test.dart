// End-to-end flow against a REAL running backend.
//
//   Terminal 1:  cd ..  &&  npm run dev:e2e
//   Terminal 2:  flutter test -d flutter-tester integration_test/app_flow_test.dart
//
// `npm run dev:e2e` drops, recreates and migrates a throwaway `<db>_e2e`
// database, seeds the pilot admin this suite logs in as, and serves the API
// on :3000 against it — so a run never touches the dev / demo database
// (same treatment `npm test` gives the Jest suite). A plain `npm run dev`
// also works but leaves this suite's users/orders in your dev database.
//
// Runs on the flutter-tester VM (no device/chromedriver needed): the real
// widget tree, real go_router, real Dio over dart:io sockets. Only the token
// store and the image picker are faked (neither has a VM implementation) —
// see `_MemoryTokenStorage` and `_FakeImagePickerPlatform` below.
//
// A generous per-test timeout: `_api` waits out the dev server's auth
// rate-limit window (up to ~60s) rather than failing when a run bunches
// enough register/verify calls together to trip it.
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
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
  Future<void> write(String token, {bool persist = true}) async => _token = token;
  @override
  Future<void> clear() async => _token = null;
}

/// A tiny but genuinely valid JPEG — the backend's `/api/uploads` route only
/// checks content-type, but the app itself re-decodes whatever URL it just
/// uploaded to show a preview (`CachedNetworkImage`), so garbage bytes throw
/// mid-decode and destabilize the widget tree for the rest of the test.
final Uint8List _fakePhotoBytes =
    Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 4)));

/// image_picker has no VM implementation, so `ImagePicker.pickImage` would
/// otherwise hang/throw on this test's headless flutter-tester binding.
/// Overriding the platform interface (the same seam Flutter's own docs
/// recommend for testing image_picker) returns a real, small in-memory file
/// instead — enough to exercise every photo-upload step end to end against
/// the live backend.
class _FakeImagePickerPlatform extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    return XFile.fromData(
      _fakePhotoBytes,
      name: 'it-photo.jpg',
      mimeType: 'image/jpeg',
    );
  }
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

/// Registers a user, completes the mandatory email+phone OTP verification
/// (every route but a couple is 403'd until both are done — see
/// `src/middleware/auth-guard.ts`'s VERIFICATION_EXEMPT_ROUTES), and fills in
/// the delivery-address fields `requireCompleteProfile` needs before either
/// side of an order can make or accept an offer. All three are dev-only
/// shortcuts a real user goes through one screen at a time; doing them here
/// via direct API calls keeps every other test's seed step working exactly
/// as it did before those gates existed.
Future<Map<String, dynamic>> _register(String kind, int stamp,
    {required String type}) async {
  final reg = await _api('POST', '/api/auth/register', body: {
    'email': 'it-$kind-$stamp@example.com',
    'full_name': '${kind[0].toUpperCase()}${kind.substring(1)} Tester',
    'user_type': type,
    'phone': '+66 81 234 5678',
    'password': 'SecurePass123!',
  });
  await _verifyAndCompleteProfile(reg['token'] as String, debugOtp: reg['debug_otp'] as Map?);
  return reg;
}

/// Verifies both OTP channels (using the codes from [debugOtp] if given,
/// otherwise fetching fresh ones via resend) and fills in a delivery
/// address, so [token] is immediately free of both the verification gate
/// and the profile-completeness gate.
Future<void> _verifyAndCompleteProfile(String token, {Map? debugOtp}) async {
  String emailCode;
  String phoneCode;
  if (debugOtp != null) {
    emailCode = debugOtp['email'] as String;
    phoneCode = debugOtp['phone'] as String;
  } else {
    final email = await _api('POST', '/api/auth/resend-otp', token: token, body: {'channel': 'email'});
    final phone = await _api('POST', '/api/auth/resend-otp', token: token, body: {'channel': 'phone'});
    emailCode = email['debug_otp'] as String;
    phoneCode = phone['debug_otp'] as String;
  }
  await _api('POST', '/api/auth/verify-otp', token: token, body: {'channel': 'email', 'code': emailCode});
  await _api('POST', '/api/auth/verify-otp', token: token, body: {'channel': 'phone', 'code': phoneCode});
  await _api('PATCH', '/api/me', token: token, body: {
    'address_street': '123 Test Street',
    'address_city': 'Bangkok',
    'address_postal_code': '10110',
    'address_country': 'TH',
  });
}

const _adminEmail = 'it-admin@example.com';
const _adminPass = 'AdminPass123';

/// Returns an admin bearer token. `npm run dev:e2e` seeds this account; if
/// login fails the server was probably started a different way.
Future<String> _adminToken() async {
  try {
    final r = await _api('POST', '/api/auth/login',
        body: {'email': _adminEmail, 'password': _adminPass});
    return r['token'] as String;
  } catch (e) {
    fail('No admin account — start the API with `npm run dev:e2e` (it seeds '
        '$_adminEmail), or run once:\n'
        '  cd ..  &&  npm run create-admin $_adminEmail $_adminPass\n'
        'Original error: $e');
  }
}

String _isoDays(int n) =>
    DateTime.now().toUtc().add(Duration(days: n)).toIso8601String();

/// Bare HTTP helper for seeding data and the health probe.
///
/// The whole suite drives one dev server from one IP, so the auth endpoints'
/// per-IP limit (`AUTH_RATE_LIMIT_MAX`, 20/min) is easy to trip across a run
/// of register/login/verify calls. A 429 isn't a failure here — wait out the
/// window the server tells us to and try again.
Future<Map<String, dynamic>> _api(
  String method,
  String path, {
  String? token,
  Map<String, dynamic>? body,
}) async {
  for (var attempt = 0;; attempt++) {
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
      if (res.statusCode == 429 && attempt < 3) {
        final retryAfter =
            int.tryParse(res.headers.value('retry-after') ?? '') ?? 60;
        await Future<void>.delayed(Duration(seconds: retryAfter + 1));
        continue;
      }
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
  throw TestFailure(
      'Timed out after $timeout waiting for: $finder\n'
      'Visible text: ${_visibleText(tester)}');
}

List<String> _visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>()
    .toList();

/// The order screen's action block, the want detail's "Make an offer" CTA and
/// the browse feed all sit below a long scroll of cards, and their vertical
/// scroll views build children lazily — so a widget past the fold has no
/// element until it's scrolled near. Like [_pumpUntil], but drags the
/// outermost vertical scrollable up each tick until [finder] resolves, then
/// makes sure it's on screen.
Future<void> _scrollUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  Finder vScroll() {
    final down = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    return down.evaluate().isNotEmpty ? down : find.byType(Scrollable);
  }

  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 150));
    if (finder.evaluate().isNotEmpty) {
      try {
        await tester.ensureVisible(finder.first);
      } catch (_) {
        // Not inside a Scrollable — fine.
      }
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }
    final sc = vScroll();
    if (sc.evaluate().isNotEmpty) {
      await tester.drag(sc.first, const Offset(0, -260));
    }
  }
  throw TestFailure(
      'Timed out after $timeout scrolling for: $finder\n'
      'Visible text: ${_visibleText(tester)}');
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

/// Opens a closed `DropdownButtonFormField` (showing its placeholder text)
/// and picks [optionText] from the menu that pops up.
Future<void> _selectDropdown(
  WidgetTester tester,
  Finder placeholderFinder,
  String optionText,
) async {
  await _tap(tester, placeholderFinder);
  await _pumpUntil(tester, find.text(optionText).last);
  await _tap(tester, find.text(optionText).last);
}

/// Taps an `ImagePickerField` showing [label] and drives its "Choose from
/// gallery" menu option, which resolves via [_FakeImagePickerPlatform].
Future<void> _pickPhoto(WidgetTester tester, String label) async {
  await _scrollUntil(tester, find.text(label).first);
  await _tap(tester, find.text(label).first);
  await _pumpUntil(tester, find.text('Choose from gallery'));
  await _tap(tester, find.text('Choose from gallery'));
  // Let the (real, against the live backend) upload complete.
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  ImagePickerPlatform.instance = _FakeImagePickerPlatform();

  setUpAll(() async {
    try {
      await _api('GET', '/health');
    } catch (e) {
      fail(
        'The Hiww API must be running on $_baseUrl for this test.\n'
        '  cd ..  &&  npm run dev:e2e\n'
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

    // Cold start, signed out → the Landing screen (not Login directly —
    // see the onboarding carousel + landing-page work in app_router.dart).
    await _pumpUntil(tester, find.text('Sign up'), timeout: const Duration(seconds: 15));
    await _tap(tester, find.text('Sign up'));
    await _pumpUntil(tester, find.text('Create your account'));

    final shopperEmail = 'it-shopper-$stamp@example.com';
    await tester.enterText(
        find.widgetWithText(TextFormField, 'First name'), 'Sam');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Surname'), 'Shopper');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), shopperEmail);
    await tester.enterText(
        find.widgetWithText(TextField, 'Phone number'), '81 234 5678');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'SecurePass123!');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'), 'SecurePass123!');
    await _tap(tester, find.text('Shop')); // user_type: shopper
    await _tap(tester, find.widgetWithText(FilledButton, 'Sign up'));

    // Real register + /api/me + feed load → the Browse feed with the seed trip.
    await _pumpUntil(tester, find.textContaining('Bangkok to Tokyo'),
        timeout: const Duration(seconds: 40));

    // Quietly clear the verification gate the same way every other test's
    // seed step does, so posting the want below doesn't hit the "Before You
    // Proceed" interstitial mid-flow — that dialog is real and worth its own
    // dedicated (lighter-weight) widget test, not this one. Landing on
    // Browse already started a background unread-count poll under the
    // not-yet-verified account, which may have queued that same dialog a
    // beat before this finishes — dismiss it if so, now that verifying below
    // has made it stale.
    final shopperToken = (await _api('POST', '/api/auth/login', body: {
      'email': shopperEmail,
      'password': 'SecurePass123!',
    }))['token'] as String;
    await _verifyAndCompleteProfile(shopperToken);
    await tester.pump(const Duration(milliseconds: 200));
    if (find.text('Before You Proceed').evaluate().isNotEmpty) {
      await _tap(tester, find.widgetWithText(TextButton, 'Cancel'));
    }

    // --- Post a want through the Create Order sheet → Summary flow. ---
    // Travel is the default tab; the want-creation FAB only shows on Order.
    await _tap(tester, find.widgetWithText(Tab, 'Order'));
    await _tap(tester, find.byType(FloatingActionButton));
    await _pumpUntil(tester, find.widgetWithText(TextField, 'Product Name'));

    await _pickPhoto(tester, 'Add a photo');
    await _pumpUntil(tester, find.widgetWithText(TextField, 'Product Name'));

    final wantTitle = 'IT Sneakers $stamp';
    await tester.enterText(
        find.widgetWithText(TextField, 'Product Name'), wantTitle);
    // "Product Details" is a heading above the field, not its label — the
    // field itself is only identifiable by its hint text.
    await tester.enterText(
        find.widgetWithText(TextField, 'Brand, model, size, colour, links'),
        'Integration-test want, safe to ignore.');

    // Buy-in: Japan / Any city. Deliver-to: Thailand / Bangkok.
    await _selectDropdown(tester, find.text('Select').first, 'Japan');
    await _selectDropdown(tester, find.text('Select').first, 'Any');
    await _selectDropdown(tester, find.text('Select').first, 'Thailand');
    await _selectDropdown(tester, find.text('Select').first, 'Bangkok');

    await _tap(tester, find.widgetWithText(FilledButton, 'Next'));
    await _pumpUntil(tester, find.text('Summary'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Submit'));

    // Submit → navigates to /wants/:id → detail screen shows the title.
    await _pumpUntil(tester, find.text(wantTitle),
        timeout: const Duration(seconds: 40));

    // And it is now the caller's want.
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
          'destination_country': 'TH',
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

    // Orders tab (Requested bucket, the default sub-tab) → the want → its offer.
    await _pumpUntil(tester, find.text('Orders'),
        timeout: const Duration(seconds: 40));
    await _tap(tester, find.text('Orders'));
    await _pumpUntil(tester, find.textContaining(wantTitle));
    await _tap(tester, find.textContaining(wantTitle));

    await _pumpUntil(tester, _button('Accept'),
        timeout: const Duration(seconds: 30));
    await _tap(tester, _button('Accept'));

    // Confirmation dialog.
    await _pumpUntil(tester, find.text('Accept this offer?'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Accept'));

    // Lands on the order screen, awaiting payment. The action block sits
    // below the stepper, trust panel and fee breakdown now, so scroll to it.
    await _scrollUntil(
        tester, find.widgetWithText(FilledButton, "I've sent the payment"),
        timeout: const Duration(seconds: 40));
    await _tap(
        tester, find.widgetWithText(FilledButton, "I've sent the payment"));

    // The order now shows the claimed-payment state.
    await _scrollUntil(tester, find.textContaining('told us you paid'),
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

    final itemDescription = 'Over-ear, noise cancelling, boxed.';
    final want = await _api('POST', '/api/requests', token: shopperToken, body: {
      'title': 'IT Headphones $stamp',
      'item_description': itemDescription,
      'source_country': 'JP',
      'destination_country': 'TH',
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
    // The traveler must record a purchase (item photo + shop receipt) before
    // the order can be marked shipped — seed it directly, the URLs only have
    // to be well-formed (no gateway fetches them during the mock AI check).
    await _api('POST', '/api/orders/$orderId/purchase-proof',
        token: travelerToken, body: {
      'image_url': '$_baseUrl/uploads/it-seed-receipt.jpg',
      'item_photo_url': '$_baseUrl/uploads/it-seed-item.jpg',
    });
    await _api('POST', '/api/orders/$orderId/deliver',
        token: travelerToken, body: {'note': 'Handed to courier'});

    // --- Shopper opens the order and confirms receipt through the UI. ---
    await tester.pumpWidget(
      ProviderScope(
        overrides: _appOverrides(shopperToken),
        child: const HiwwApp(),
      ),
    );

    await _pumpUntil(tester, find.text('Orders'),
        timeout: const Duration(seconds: 40));
    await _tap(tester, find.text('Orders'));
    // A shipped order lives under the "In Transit" sub-tab, not the default
    // "Requested" one.
    await _pumpUntil(tester, find.textContaining('In Transit'),
        timeout: const Duration(seconds: 20));
    await _tap(tester, find.textContaining('In Transit'));
    await _pumpUntil(tester, find.textContaining(itemDescription),
        timeout: const Duration(seconds: 30));
    await _tap(tester, find.textContaining(itemDescription));

    // Order screen, in transit → a delivery photo is required before
    // "Confirm & release" is even enabled (migration 034).
    await _scrollUntil(tester, find.text('Upload a photo of the item received'),
        timeout: const Duration(seconds: 30));
    await _pickPhoto(tester, 'Upload a photo of the item received');
    await _scrollUntil(tester, _button('Confirm & release'),
        timeout: const Duration(seconds: 20));
    await _tap(tester, _button('Confirm & release'));

    // "Release {total}?" confirmation dialog — its confirm button reads
    // "Release payment".
    await _pumpUntil(tester, find.widgetWithText(FilledButton, 'Release payment'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Release payment'));

    // Release happens immediately, then pushes straight to the rating step
    // (no separate confirm step left — see order_screen.dart's
    // _confirmAndReview).
    await _pumpUntil(tester, find.text('Leave a review'),
        timeout: const Duration(seconds: 30));
    await tester.enterText(
        find.byType(TextField).last, 'Smooth handover, thanks!');
    // Starts unrated on purpose — tap the 5th star.
    await _tap(tester, find.byTooltip('5 stars'));
    await _scrollUntil(tester, find.widgetWithText(FilledButton, 'Close'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Close'));

    // Back on the order, now delivered + rated.
    await _scrollUntil(tester, find.textContaining('You rated'),
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
          'source_country': 'JP', 'destination_country': 'TH', 'category': 'other',
          'estimated_weight_kg': 1.0, 'budget': '3000.00',
        });

    await tester.pumpWidget(
      ProviderScope(
          overrides: _appOverrides(travelerToken), child: const HiwwApp()),
    );

    // Home opens on the Travel tab (which browses trips); wants are on the
    // Order tab.
    await _pumpUntil(tester, find.widgetWithText(Tab, 'Order'),
        timeout: const Duration(seconds: 30));
    await _tap(tester, find.widgetWithText(Tab, 'Order'));
    await _scrollUntil(tester, find.textContaining(wantTitle),
        timeout: const Duration(seconds: 40));
    await _tap(tester, find.textContaining(wantTitle));

    await _scrollUntil(tester, _button('Make an offer'),
        timeout: const Duration(seconds: 30));
    await _tap(tester, _button('Make an offer'));

    // MakeOfferScreen: trip is pre-selected; set a price and a delivery date.
    await _pumpUntil(tester, find.widgetWithText(TextField, 'Your price for the item'),
        timeout: const Duration(seconds: 20));
    await tester.enterText(
        find.widgetWithText(TextField, 'Your price for the item'), '2800');
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Pick a date'));
    // The picker opens on the trip's return date; delivery has to be strictly
    // after it, so advance a month and pick a mid-month day.
    await _pumpUntil(tester, find.byTooltip('Next month'));
    await _tap(tester, find.byTooltip('Next month'));
    await _tap(tester, find.text('15'));
    await _tap(tester, find.text('OK'));
    await _scrollUntil(tester, _button('Send offer'));
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

    final itemDescription = 'Electric kettle, 1L, from any Tokyo store.';
    final want = await _api('POST', '/api/requests', token: shopperToken, body: {
      'title': 'IT Kettle $stamp',
      'item_description': itemDescription,
      'source_country': 'JP', 'destination_country': 'TH', 'category': 'other',
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

    await _pumpUntil(tester, find.text('Orders'),
        timeout: const Duration(seconds: 40));
    await _tap(tester, find.text('Orders'));
    await _pumpUntil(tester, find.textContaining(itemDescription),
        timeout: const Duration(seconds: 30));
    await _tap(tester, find.textContaining(itemDescription));

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
        tester, find.widgetWithText(TextField, 'First name (as on document)'));
    await tester.enterText(
        find.widgetWithText(TextField, 'First name (as on document)'), 'Kyc');
    await tester.enterText(
        find.widgetWithText(TextField, 'Last name (as on document)'),
        'Testuser');
    await tester.enterText(
        find.widgetWithText(TextField, 'Document number'), 'X1234567');
    await tester.enterText(
        find.widgetWithText(TextField, 'Address (as on document)'),
        '123 Test St, Bangkok');
    await tester.enterText(
        find.widgetWithText(TextField, 'Contact number'), '+66 81 234 5678');
    await _pickPhoto(tester, 'Add a photo of the document');
    await _pickPhoto(tester, 'Add a selfie holding the document');
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

    final itemDescription = 'USB-C 65W GaN charger, boxed.';
    final want = await _api('POST', '/api/requests', token: shopperToken, body: {
      'title': 'IT Charger $stamp',
      'item_description': itemDescription,
      'source_country': 'JP', 'destination_country': 'TH', 'category': 'other',
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

    // Orders tab → Requested bucket (the default sub-tab) — a confirmed
    // order sits there until it's bought+shipped, same bucket a pending
    // want or negotiation would be in.
    await _pumpUntil(tester, find.text('Orders'),
        timeout: const Duration(seconds: 40));
    await _tap(tester, find.text('Orders'));
    await _pumpUntil(tester, find.textContaining(itemDescription),
        timeout: const Duration(seconds: 30));
    await _tap(tester, find.textContaining(itemDescription));

    // A confirmed order needs a purchase recorded first — upload the item
    // photo and the shop receipt, submit, and only then does "Mark as
    // shipped" appear.
    await _scrollUntil(tester, find.text('Upload item photo'),
        timeout: const Duration(seconds: 30));
    await _pickPhoto(tester, 'Upload item photo');
    await _pickPhoto(tester, 'Upload purchase receipt');
    await _scrollUntil(tester, _button('Submit'));
    await _tap(tester, _button('Submit'));

    await _scrollUntil(tester, _button('Mark as shipped'),
        timeout: const Duration(seconds: 30));
    await _tap(tester, _button('Mark as shipped'));

    await _scrollUntil(tester, find.textContaining('Waiting for the shopper'),
        timeout: const Duration(seconds: 30));

    final order = await _api('GET', '/api/orders/$orderId', token: travelerToken);
    expect(order['status'], 'in_transit');
  });

  testWidgets('shopper messages the traveler on an order, leakage is redacted',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final stamp = DateTime.now().millisecondsSinceEpoch;

    final shopper = await _register('shopper', stamp, type: 'shopper');
    final traveler = await _register('traveler', stamp, type: 'traveler');
    final shopperToken = shopper['token'] as String;
    final travelerToken = traveler['token'] as String;

    final itemDescription = 'Instant camera, boxed, from any Tokyo store.';
    final want = await _api('POST', '/api/requests', token: shopperToken, body: {
      'title': 'IT Chat $stamp',
      'item_description': itemDescription,
      'source_country': 'JP', 'destination_country': 'TH', 'category': 'other',
      'estimated_weight_kg': 1.0, 'budget': '6000.00',
    });
    final trip = await _api('POST', '/api/trips', token: travelerToken, body: {
      'departure_country': 'TH', 'arrival_country': 'JP',
      'departure_date': _isoDays(3), 'return_date': _isoDays(13),
      'max_weight_kg': 6, 'max_items': 3,
    });
    final offer = await _api('POST', '/api/offers', token: travelerToken, body: {
      'request_id': want['id'], 'trip_id': trip['id'],
      'quoted_price': '5500.00', 'delivery_date': _isoDays(10),
    });
    final accept = await _api('POST', '/api/offers/${offer['id']}/accept',
        token: shopperToken);
    final orderId = accept['order_id'] as String;
    // Order is at pending_payment — chat is open (only delivered/cancelled,
    // 24h after the fact, ever closes it).

    await tester.pumpWidget(
      ProviderScope(
          overrides: _appOverrides(shopperToken), child: const HiwwApp()),
    );

    await _pumpUntil(tester, find.text('Orders'),
        timeout: const Duration(seconds: 40));
    await _tap(tester, find.text('Orders'));
    await _pumpUntil(tester, find.textContaining(itemDescription),
        timeout: const Duration(seconds: 30));
    await _tap(tester, find.textContaining(itemDescription));

    await _scrollUntil(tester, find.widgetWithText(OutlinedButton, 'Open chat'),
        timeout: const Duration(seconds: 30));
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Open chat'));

    // Composer → type → send. (The chat screen's only TextField.)
    await _pumpUntil(tester, find.byTooltip('Send'),
        timeout: const Duration(seconds: 20));
    const plain = 'Hi! Any preference on the colour?';
    await tester.enterText(find.byType(TextField).last, plain);
    await _tap(tester, find.byTooltip('Send'));
    await _pumpUntil(tester, find.text(plain), timeout: const Duration(seconds: 20));

    // A phone number is redacted in place before the message is ever stored.
    await tester.enterText(
        find.byType(TextField).last, 'reach me on 0812345678 maybe');
    await _tap(tester, find.byTooltip('Send'));
    await _pumpUntil(tester, find.textContaining('[number hidden]'),
        timeout: const Duration(seconds: 20));

    // Backend: the traveler sees both, and the raw number was never stored.
    final msgs = await _api('GET', '/api/orders/$orderId/messages',
        token: travelerToken);
    final bodies = (msgs['items'] as List)
        .map((m) => (m as Map)['body'] as String)
        .toList();
    expect(bodies, contains(plain));
    expect(bodies.any((b) => b.contains('[number hidden]')), isTrue);
    expect(bodies.every((b) => !b.contains('0812345678')), isTrue);
  });
}
