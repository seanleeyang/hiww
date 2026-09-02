import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Compile-time override, e.g.
/// `flutter run --dart-define=HIWW_API_BASE_URL=http://192.168.1.20:3000`
const _override = String.fromEnvironment('HIWW_API_BASE_URL');

/// Resolves the backend base URL.
///
/// - explicit `--dart-define` always wins
/// - web / iOS simulator / desktop → `http://localhost:3000`
/// - Android emulator → `http://10.0.2.2:3000` (its alias for the host loopback)
///
/// A physical device must pass `--dart-define=HIWW_API_BASE_URL=http://<lan-ip>:3000`.
String resolveApiBaseUrl() {
  if (_override.isNotEmpty) return _override;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://localhost:3000';
}
