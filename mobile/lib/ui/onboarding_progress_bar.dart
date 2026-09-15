import 'package:flutter/material.dart';

/// A thin continuous top progress bar spanning [totalSteps] steps — shared
/// by the onboarding carousel and the landing screen so "how far through
/// sign-up" reads as one continuous bar across both, rather than each
/// screen having its own separate indicator.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({super.key, required this.step, required this.totalSteps});

  /// 0-based current step.
  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = ((step + 1) / totalSteps).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 4, width: constraints.maxWidth, color: scheme.surfaceContainerHigh),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  height: 4,
                  width: constraints.maxWidth * fraction,
                  decoration: BoxDecoration(
                    color: scheme.onSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
