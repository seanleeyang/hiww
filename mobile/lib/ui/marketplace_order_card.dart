import 'package:flutter/material.dart';

import 'hero_image.dart';
import 'soft_card.dart';
import 'status_pill.dart';

/// The one card shape used everywhere under the Orders tab — a want still
/// waiting for offers, an offer being negotiated (either side), or an order
/// in flight. Previously each of those had its own layout (status pill in a
/// different spot, two of the three with no photo at all); this standardizes
/// on: photo, product name (+ optional subtitle), status pill, price, and a
/// "what happens next" line.
class MarketplaceOrderCard extends StatelessWidget {
  const MarketplaceOrderCard({
    super.key,
    required this.imageUrl,
    required this.fallbackAsset,
    required this.title,
    this.subtitle,
    required this.status,
    required this.priceLabel,
    this.ctaIcon,
    this.ctaText,
    this.onTap,
    this.trailing,
  });

  final String? imageUrl;
  final String fallbackAsset;
  final String title;
  final String? subtitle;
  final String status;

  /// The current negotiated price while an offer is pending, or the final
  /// price once there's an order — whichever this card actually has.
  final String priceLabel;

  /// "What happens next", from this viewer's point of view — omitted when
  /// there's nothing actionable left to say.
  final IconData? ctaIcon;
  final String? ctaText;

  final VoidCallback? onTap;

  /// A small control next to the status pill — e.g. a "remove from list"
  /// close button on a cancelled want.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: HeroImage(
                url: imageUrl,
                fallbackAsset: fallbackAsset,
                height: 56,
                borderRadius: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    StatusPill(status),
                    if (trailing != null) ...[const SizedBox(width: 4), trailing!],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 8),
                Text(priceLabel, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                if (ctaText != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (ctaIcon != null) ...[
                        Icon(ctaIcon, size: 13, color: scheme.primary),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          ctaText!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
