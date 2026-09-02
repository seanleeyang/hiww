import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/offer.dart';

class OffersRepository {
  OffersRepository(this._api);
  final ApiClient _api;

  Future<String> create({
    required String requestId,
    required String tripId,
    required String quotedPrice,
    required DateTime deliveryDate,
  }) async {
    final data = await _api.post('/api/offers', body: {
      'request_id': requestId,
      'trip_id': tripId,
      'quoted_price': quotedPrice,
      'delivery_date': deliveryDate.toUtc().toIso8601String(),
    });
    return (data as Map)['id'].toString();
  }

  Future<List<Offer>> mine() async {
    final data = await _api.get('/api/offers/mine');
    final items = ((data as Map)['items'] as List?) ?? [];
    return items.map((e) => Offer.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}

final offersRepositoryProvider = Provider<OffersRepository>(
  (ref) => OffersRepository(ref.watch(apiClientProvider)),
);

final myOffersProvider =
    FutureProvider<List<Offer>>((ref) => ref.watch(offersRepositoryProvider).mine());
