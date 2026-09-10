import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/hero_image.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/stock_images.dart';
import '../../shared/domain/user_summary.dart';
import '../../trips/domain/trip.dart';
import '../../wants/domain/want.dart';

class TripFeedCard extends StatelessWidget {
  const TripFeedCard({
    super.key,
    required this.trip,
    this.traveler,
    this.earnMin,
    this.earnMax,
    this.matchCount = 0,
    this.onTap,
  });

  final Trip trip;
  final UserSummary? traveler;
  final String? earnMin;
  final String? earnMax;
  final int matchCount;
  final VoidCallback? onTap;

  /// Below this, a lone match's payout reads as unimpressive rather than
  /// enticing — skip the badge and let the match-count line speak instead.
  static const _earnBadgeFloor = 300;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showEarnBadge =
        earnMin != null && earnMax != null && (double.tryParse(earnMax!) ?? 0) >= _earnBadgeFloor;
    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              HeroImage(
                url: trip.coverImageUrl,
                fallbackAsset: stockForTrip(city: trip.arrivalCity, countryCode: trip.arrivalCountry),
                height: 150,
                borderRadius: 20,
                heroTag: 'trip-${trip.id}',
              ),
              if (showEarnBadge)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: EarnBadge(label: earnRangeLabel(earnMin, earnMax)),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (traveler != null) AvatarRating(user: traveler!),
                const SizedBox(height: 10),
                RouteChip(route: trip.route, dates: trip.dates),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (trip.maxWeightKg > 0)
                      IconLine(
                        Icons.luggage_outlined,
                        l10n.feedTripWeightFree(
                          trip.maxWeightKg.toStringAsFixed(trip.maxWeightKg % 1 == 0 ? 0 : 1),
                        ),
                      ),
                    if (trip.maxWeightKg > 0 && matchCount > 0)
                      const SizedBox(width: 14),
                    if (matchCount > 0)
                      IconLine(Icons.favorite_outline, l10n.feedTripMatchCount(matchCount)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WantFeedCard extends StatelessWidget {
  const WantFeedCard({
    super.key,
    required this.want,
    this.shopper,
    this.matchCount = 0,
    this.onTap,
  });

  final Want want;
  final UserSummary? shopper;
  final int matchCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (shopper != null)
                Expanded(child: AvatarRating(user: shopper!, dense: true)),
              Text(
                l10n.feedWantSourceLabel(want.sourceLabel),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: HeroImage(
                    url: want.imageUrl,
                    fallbackAsset: stockForCategory(want.category),
                    height: 88,
                    borderRadius: 12,
                    heroTag: 'want-${want.id}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      want.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        IconLine(Icons.sell_outlined, l10n.feedWantBudgetLabel(want.budgetLabel)),
                        if (want.needByLabel != null)
                          IconLine(Icons.event_outlined, want.needByLabel!),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (matchCount > 0) ...[
            const SizedBox(height: 12),
            RouteMatchHint(text: l10n.feedWantMatchCount(matchCount)),
          ],
        ],
      ),
    );
  }
}
