import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the bearer token issued by `/api/auth/*`.
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'hiww_token';

  /// Holds the token when the user unchecked "Stay signed in" at login — kept
  /// for the rest of this app run but never written to disk, so a full app
  /// restart signs them out again instead of coming back automatically.
  String? _sessionOnly;

  /// Whether the current token is in "don't persist" mode — so a caller
  /// replacing the token (e.g. after a password change) can keep it that
  /// way instead of silently upgrading the session to survive an app
  /// restart when the user explicitly chose not to.
  bool get isSessionOnly => _sessionOnly != null;

  Future<String?> read() async => _sessionOnly ?? await _storage.read(key: _key);

  /// [persist] false keeps the token in memory only (see [_sessionOnly])
  /// instead of writing it to secure storage.
  Future<void> write(String token, {bool persist = true}) async {
    if (persist) {
      _sessionOnly = null;
      await _storage.write(key: _key, value: token);
    } else {
      _sessionOnly = token;
      await _storage.delete(key: _key);
    }
  }

  Future<void> clear() async {
    _sessionOnly = null;
    await _storage.delete(key: _key);
  }
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(const FlutterSecureStorage()),
);
