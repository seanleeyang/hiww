import 'package:flutter/material.dart';

import '../features/shared/domain/user_summary.dart';
import '../theme/app_colors.dart';
import 'initials_avatar.dart';
import 'star_rating.dart';

/// "Bangkok to Tokyo" with "12 Nov 2026 to 19 Nov 2026" below — stacked
/// rather than joined on one line, since spelled-out routes and full dates
/// are too long to fit a single line on a phone-width card.
class RouteChip extends StatelessWidget {
  const RouteChip({super.key, required this.route, this.dates});
  final String route;
  final String? dates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            route,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (dates != null && dates!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              dates!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Coral pill: "Earn up to ฿1,200"
class EarnBadge extends StatelessWidget {
  const EarnBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class IconLine extends StatelessWidget {
  const IconLine(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Avatar + name + "4.9 · 147 delivered".
class AvatarRating extends StatelessWidget {
  const AvatarRating({super.key, required this.user, this.radius = 18, this.dense = false});

  final UserSummary user;
  final double radius;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InitialsAvatar(name: user.fullName, url: user.avatarUrl, radius: radius),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.fullName,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: dense ? 13 : 14),
            ),
            const SizedBox(height: 1),
            StarRatingDisplay(
              rating: user.ratingAvg,
              size: 12,
              trailing: user.deliveredCount > 0 ? '${user.deliveredCount} delivered' : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// "3 travelers on this route" style hint.
class RouteMatchHint extends StatelessWidget {
  const RouteMatchHint({super.key, required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hiww = context.hiww;
    return Material(
      color: hiww.infoSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.groups_outlined, size: 18, color: hiww.success),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
              if (onTap != null) const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
