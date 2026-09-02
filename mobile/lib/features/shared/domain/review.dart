import '../../../core/format.dart';
import 'user_summary.dart';

class Review {
  const Review({
    required this.id,
    required this.rating,
    this.comment,
    this.createdAt,
    required this.reviewerName,
    this.reviewerAvatarUrl,
  });

  final String id;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final String reviewerName;
  final String? reviewerAvatarUrl;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'].toString(),
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        comment: (j['comment'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['comment'] as String,
        createdAt: parseDate(j['created_at']),
        reviewerName: (j['reviewer_name'] ?? '').toString(),
        reviewerAvatarUrl: (j['reviewer_avatar_url'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['reviewer_avatar_url'] as String,
      );
}

class ReviewSummary {
  const ReviewSummary({required this.user, required this.items});

  final UserSummary user;
  final List<Review> items;

  factory ReviewSummary.fromJson(Map<String, dynamic> j) => ReviewSummary(
        user: UserSummary.fromJson(j['user']) ??
            const UserSummary(id: '', fullName: ''),
        items: ((j['items'] as List?) ?? [])
            .map((e) => Review.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
