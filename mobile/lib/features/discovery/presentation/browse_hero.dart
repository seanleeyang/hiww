import 'package:flutter/material.dart';

/// The colored greeting banner at the top of each Browse tab (Order/Travel)
/// — a personalized "what do you want to do" prompt plus one CTA button,
/// styled after a competitor's home screen but without any fabricated
/// stats/social-proof row, since Hiww is a new pilot with no numbers like
/// that to show yet.
class BrowseHero extends StatelessWidget {
  const BrowseHero({
    super.key,
    required this.greeting,
    required this.tagline,
    required this.ctaLabel,
    required this.onCta,
    required this.background,
    required this.foreground,
  });

  final String greeting;
  final String tagline;
  final String ctaLabel;
  final VoidCallback onCta;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      color: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: TextStyle(
              color: foreground,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tagline,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onCta,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ctaLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
