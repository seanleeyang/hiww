import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/offer.dart';
import '../domain/want.dart';

class WantsRepository {
  WantsRepository(this._api);
  final ApiClient _api;

  Future<String> create({
    required String title,
    required String itemDescription,
    required String sourceCountry,
    String? sourceCity,
    required String category,
    required double estimatedWeightKg,
    required String budget,
    DateTime? needBy,
    String? imageUrl,
  }) async {
    final body = <String, dynamic>{
      'item_description': itemDescription,
      'source_country': sourceCountry,
      'category': category,
      'estimated_weight_kg': estimatedWeightKg,
      'budget': budget,
      'title': title,
    };
    if (sourceCity != null && sourceCity.isNotEmpty) body['source_city'] = sourceCity;
    if (needBy != null) body['need_by'] = needBy.toUtc().toIso8601String();
    if (imageUrl != null && imageUrl.isNotEmpty) body['image_url'] = imageUrl;
    final data = await _api.post('/api/requests', body: body);
    return (data as Map)['id'].toString();
  }

  Future<List<Want>> mine() async {
    final data = await _api.get('/api/requests/mine');
    final items = ((data as Map)['items'] as List?) ?? [];
    return items.map((e) => Want.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<WantDetail> byId(String id) async {
    final data = await _api.get('/api/requests/$id');
    return WantDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<Offer>> offersFor(String requestId) async {
    final data = await _api.get('/api/requests/$requestId/offers');
    final items = ((data as Map)['items'] as List?) ?? [];
    return items.map((e) => Offer.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Returns the created order id.
  Future<String> acceptOffer(String offerId) async {
    final data = await _api.post('/api/offers/$offerId/accept');
    return (data as Map)['order_id'].toString();
  }
}

final wantsRepositoryProvider = Provider<WantsRepository>(
  (ref) => WantsRepository(ref.watch(apiClientProvider)),
);

final myWantsProvider =
    FutureProvider<List<Want>>((ref) => ref.watch(wantsRepositoryProvider).mine());

final wantDetailProvider = FutureProvider.family<WantDetail, String>(
  (ref, id) => ref.watch(wantsRepositoryProvider).byId(id),
);

final wantOffersProvider = FutureProvider.family<List<Offer>, String>(
  (ref, id) => ref.watch(wantsRepositoryProvider).offersFor(id),
);
