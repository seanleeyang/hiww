import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/review.dart';

class ReviewsRepository {
  ReviewsRepository(this._api);
  final ApiClient _api;

  Future<ReviewSummary> forUser(String userId) async {
    final data = await _api.get('/api/users/$userId/reviews');
    return ReviewSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> submit(String orderId, {required int rating, String? comment}) async {
    await _api.post('/api/orders/$orderId/review', body: {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>(
  (ref) => ReviewsRepository(ref.watch(apiClientProvider)),
);

final userReviewsProvider = FutureProvider.family<ReviewSummary, String>(
  (ref, userId) => ref.watch(reviewsRepositoryProvider).forUser(userId),
);
