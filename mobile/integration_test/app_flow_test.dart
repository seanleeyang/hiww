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
  _MemoryTokenStorage() : super(const FlutterSecureStorage());
  String? _token;
  @override
  Future<String?> read() async => _token;
  @override
  Future<void> write(String token) async => _token = token;
  @override
  Future<void> clear() async => _token = null;
}

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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
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
    final traveler = await _api('POST', '/api/auth/register', body: {
      'email': 'it-traveler-$stamp@example.com',
      'full_name': 'Ida Traveler',
      'user_type': 'traveler',
      'password': 'SecurePass123!',
    });
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
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
          apiClientProvider.overrideWith(
            (ref) => ApiClient(
              baseUrl: _baseUrl,
              tokenStorage: ref.watch(tokenStorageProvider),
            ),
          ),
        ],
        child: const HiwwApp(),
      ),
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
    final mine = await _api('GET', '/api/requests/mine',
        token: (await _api('POST', '/api/auth/login', body: {
          'email': 'it-shopper-$stamp@example.com',
          'password': 'SecurePass123!',
        }))['token'] as String);
    expect(
      (mine['items'] as List).any((w) => (w as Map)['title'] == wantTitle),
      isTrue,
      reason: 'the new want should appear in /api/requests/mine',
    );
  });
}
