import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/central_video.dart';
import '../../../ui/entrance_fade.dart';
import '../../../ui/floating_orbit_illustration.dart';
import '../../../ui/language_toggle.dart';
import '../../../ui/onboarding_progress_bar.dart';
import '../application/onboarding_controller.dart';

/// Total steps the top progress bar spans — just the 3 onboarding slides,
/// so it fills on the last one ("Earn on trips you already take"), matching
/// Wise's app. The landing/sign-up screen after it has no progress bar of
/// its own.
const onboardingTotalSteps = 3;

class _Slide {
  const _Slide(this.icon, this.satelliteIcons, this.title, this.body, {this.videoAsset});
  final IconData icon;
  final List<IconData> satelliteIcons;
  final String title;
  final String body;
  final String? videoAsset;
}

/// Signed-out welcome carousel, shown once per device before the landing
/// screen — see the redirect logic in `app_router.dart`.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (mounted) context.go('/landing');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final slides = [
      _Slide(
        Icons.travel_explore_outlined,
        const [Icons.shopping_bag_outlined, Icons.public],
        l10n.onboardingSlide1Title,
        l10n.onboardingSlide1Body,
      ),
      _Slide(
        Icons.flight_takeoff_outlined,
        const [Icons.luggage_outlined, Icons.person_outline],
        l10n.onboardingSlide2Title,
        l10n.onboardingSlide2Body,
      ),
      _Slide(
        Icons.savings_outlined,
        const [],
        l10n.onboardingSlide3Title,
        l10n.onboardingSlide3Body,
        videoAsset: 'assets/video/piggy_bank.mp4',
      ),
    ];
    final lastPage = _page == slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: LanguageToggle(),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: Text(l10n.actionSkip),
                  ),
                ],
              ),
            ),
            OnboardingProgressBar(step: _page, totalSteps: onboardingTotalSteps),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [for (final s in slides) _SlideView(slide: s)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: FilledButton(
                onPressed: lastPage
                    ? _finish
                    : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                child: Text(lastPage ? l10n.actionGetStarted : l10n.actionNext),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bold display style used for onboarding/landing headlines only —
/// Futura Condensed Extra Bold (see pubspec.yaml for the licensing note).
/// The rest of the app keeps its Manrope body font.
TextStyle onboardingHeadlineStyle(BuildContext context) => Theme.of(context)
    .textTheme
    .headlineMedium!
    .copyWith(
      fontFamily: 'FuturaCondensedExtraBold',
      fontWeight: FontWeight.w800,
      height: 1.05,
      letterSpacing: -0.5,
    );

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return EntranceFade(
      child: Column(
        children: [
          if (slide.videoAsset != null)
            // Fills the whole gap between the progress bar above and the
            // headline below, and centers the video in it — edge-to-edge
            // horizontally (no side padding, unlike the icon slides), with
            // the aspect ratio still locked to the source video's own
            // shape (square, 1440x1440) so it scales proportionally rather
            // than stretching.
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CentralVideo(asset: slide.videoAsset!),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 12),
            FloatingOrbitIllustration(icon: slide.icon, satelliteIcons: slide.satelliteIcons),
            const Spacer(flex: 3),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(
                  slide.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: onboardingHeadlineStyle(context),
                ),
                const SizedBox(height: 14),
                Text(
                  slide.body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
