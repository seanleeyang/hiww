import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/onboarding_storage.dart';

/// Whether the signed-out welcome carousel has already been shown on this
/// device. Read by the router's redirect logic — see `app_router.dart`.
class OnboardingController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(onboardingStorageProvider).hasSeenOnboarding();

  Future<void> markSeen() async {
    await ref.read(onboardingStorageProvider).markSeen();
    state = const AsyncData(true);
  }
}

final onboardingSeenProvider = AsyncNotifierProvider<OnboardingController, bool>(
  OnboardingController.new,
);
