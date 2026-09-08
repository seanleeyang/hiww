import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Whether the signed-out welcome carousel has already been shown once on
/// this device — it should only ever appear on a person's first launch.
class OnboardingStorage {
  OnboardingStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'hiww_onboarding_seen';

  Future<bool> hasSeenOnboarding() async => (await _storage.read(key: _key)) == 'true';
  Future<void> markSeen() => _storage.write(key: _key, value: 'true');
}

final onboardingStorageProvider = Provider<OnboardingStorage>(
  (ref) => OnboardingStorage(const FlutterSecureStorage()),
);
