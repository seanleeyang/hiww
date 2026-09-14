import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/language_toggle.dart';
import '../application/onboarding_controller.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
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
    final scheme = Theme.of(context).colorScheme;
    final slides = [
      _Slide(Icons.travel_explore_outlined, l10n.onboardingSlide1Title, l10n.onboardingSlide1Body),
      _Slide(Icons.flight_takeoff_outlined, l10n.onboardingSlide2Title, l10n.onboardingSlide2Body),
      _Slide(Icons.savings_outlined, l10n.onboardingSlide3Title, l10n.onboardingSlide3Body),
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
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [for (final s in slides) _SlideView(slide: s)],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
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
                // Pill-shaped, matching the warmer look explored on the design
                // canvas — a local override rather than a theme-wide change,
                // since the rest of the app keeps HiwwRadii.button.
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                child: Text(lastPage ? l10n.actionGetStarted : l10n.actionNext),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                slide.body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(child: _SlideIllustration(icon: slide.icon)),
      ],
    );
  }
}

/// The warm gradient "hill" behind each slide's icon — replaces the old
/// flat circle. Bottom-anchored and fills whatever vertical space the
/// slide has left, same shape language as the design canvas exploration.
class _SlideIllustration extends StatelessWidget {
  const _SlideIllustration({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(120)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(scheme.primary, Colors.white, 0.2)!,
              scheme.primary,
              scheme.onSurface,
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 40,
              left: 48,
              child: _softDot(size: 10, opacity: 0.35),
            ),
            Positioned(
              top: 70,
              right: 56,
              child: _softDot(size: 6, opacity: 0.4),
            ),
            Positioned(
              bottom: 60,
              left: 36,
              child: _softDot(size: 14, opacity: 0.18),
            ),
            Icon(icon, size: 88, color: scheme.primaryContainer),
          ],
        ),
      ),
    );
  }

  Widget _softDot({required double size, required double opacity}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}
