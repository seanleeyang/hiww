import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's chosen app language ('en' or 'th'). `null` means
/// "follow the system locale" — never explicitly chosen.
class LocaleStorage {
  LocaleStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'hiww_locale';

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String languageCode) => _storage.write(key: _key, value: languageCode);
}

final localeStorageProvider = Provider<LocaleStorage>(
  (ref) => LocaleStorage(const FlutterSecureStorage()),
);
