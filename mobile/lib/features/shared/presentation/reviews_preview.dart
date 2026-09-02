import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../ui/initials_avatar.dart';
import '../../../ui/section_header.dart';
import '../../../ui/star_rating.dart';
import '../data/reviews_repository.dart';

/// Compact list of a user's most recent reviews for a detail screen.
class ReviewsPreview extends ConsumerWidget {
  const ReviewsPreview({super.key, required this.userId, this.max = 3});

  final String userId;
  final int max;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(userReviewsProvider(userId));
    return reviews.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (summary) {
        if (summary.items.isEmpty) return const SizedBox.shrink();
        final shown = summary.items.take(max).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              'Reviews (${summary.user.ratingCount})',
              action: StarRatingDisplay(rating: summary.user.ratingAvg),
            ),
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
