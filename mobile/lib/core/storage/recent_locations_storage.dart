import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The last few cities picked in the "Traveling from/to" search sheet, most
/// recent first — shown above the full city list so a repeat search is one
/// tap instead of typing again. Stored as a simple delimited string (no city
/// name in this app's curated list contains the delimiter), same pattern as
/// [OnboardingStorage]/`LocaleStorage`.
class RecentLocationsStorage {
  RecentLocationsStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'hiww_recent_locations';
  static const _max = 5;

  Future<List<String>> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return const [];
    return raw.split('|');
  }

  Future<void> add(String city) async {
    final current = await read();
    final next = [city, ...current.where((c) => c != city)].take(_max).toList();
    await _storage.write(key: _key, value: next.join('|'));
  }
}

final recentLocationsStorageProvider = Provider<RecentLocationsStorage>(
  (ref) => RecentLocationsStorage(const FlutterSecureStorage()),
);
