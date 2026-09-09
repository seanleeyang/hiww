import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../ui/initials_avatar.dart';
import '../../../ui/star_rating.dart';
import '../data/reviews_repository.dart';

/// Compact list of a user's most recent reviews for a detail screen.
/// Collapsed by default so it doesn't push more actionable content (offers,
/// negotiation controls) further down the page — tap the header to expand.
class ReviewsPreview extends ConsumerStatefulWidget {
  const ReviewsPreview({super.key, required this.userId, this.max = 3});

  final String userId;
  final int max;

  @override
  ConsumerState<ReviewsPreview> createState() => _ReviewsPreviewState();
}

class _ReviewsPreviewState extends ConsumerState<ReviewsPreview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final reviews = ref.watch(userReviewsProvider(widget.userId));
    return reviews.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (summary) {
        if (summary.items.isEmpty) return const SizedBox.shrink();
        final shown = summary.items.take(widget.max).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reviews (${summary.user.ratingCount})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    StarRatingDisplay(rating: summary.user.ratingAvg),
                    const SizedBox(width: 4),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
            if (_expanded)
              for (final r in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InitialsAvatar(
                            name: r.reviewerName,
                            url: r.reviewerAvatarUrl,
                            radius: 13,
                          ),
                          const SizedBox(width: 8),
                          Text(r.reviewerName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const Spacer(),
                          StarRatingDisplay(rating: r.rating.toDouble(), size: 12),
                        ],
                      ),
                      if (r.comment != null) ...[
                        const SizedBox(height: 4),
                        Text(r.comment!,
                            style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                      if (r.createdAt != null)
                        Text(dateLong(r.createdAt),
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}
