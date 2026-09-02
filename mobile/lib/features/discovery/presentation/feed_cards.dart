import 'package:flutter/material.dart';

import '../../../core/format.dart';
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
    this.earnEstimate,
    this.matchCount = 0,
    this.onTap,
  });

  final Trip trip;
  final UserSummary? traveler;
  final String? earnEstimate;
  final int matchCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
                fallbackAsset: stockForCountry(trip.arrivalCountry),
                height: 150,
                borderRadius: 20,
              ),
              if (earnEstimate != null)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: EarnBadge(label: 'Earn up to ${money(earnEstimate)}'),
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
                      IconLine(Icons.luggage_outlined,
                          '${trip.maxWeightKg.toStringAsFixed(trip.maxWeightKg % 1 == 0 ? 0 : 1)} kg free'),
                    if (trip.maxWeightKg > 0 && matchCount > 0)
                      const SizedBox(width: 14),
                    if (matchCount > 0)
                      IconLine(Icons.favorite_outline,
                          '${pluralize(matchCount, 'want')} on this route'),
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
                'wants from ${want.sourceLabel}',
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
                        IconLine(Icons.sell_outlined, 'Budget ${want.budgetLabel}'),
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
            RouteMatchHint(
              text: '${pluralize(matchCount, 'traveler')} on this route',
            ),
          ],
        ],
      ),
    );
  }
}
