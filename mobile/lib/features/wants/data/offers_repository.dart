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

  /// Every negotiation the caller is part of, on either side — as the
  /// traveler who made an offer, or the shopper who owns the want it's on.
  Future<List<Offer>> negotiations() async {
    final data = await _api.get('/api/offers/negotiations');
    final items = ((data as Map)['items'] as List?) ?? [];
    return items.map((e) => Offer.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Returns the created order id.
  Future<String> accept(String offerId) async {
    final data = await _api.post('/api/offers/$offerId/accept');
    return (data as Map)['order_id'].toString();
  }

  /// Propose a different price. Throws [ApiException] (409) if it isn't your
  /// turn or the 2-counter limit has been reached.
  Future<void> counter(String offerId, String quotedPrice) async {
    await _api.post('/api/offers/$offerId/counter', body: {'quoted_price': quotedPrice});
  }

  /// Decline the offer's current price outright, ending the negotiation.
  Future<void> reject(String offerId) async {
    await _api.post('/api/offers/$offerId/reject');
  }
}

final offersRepositoryProvider = Provider<OffersRepository>(
  (ref) => OffersRepository(ref.watch(apiClientProvider)),
);

final myOffersProvider =
    FutureProvider<List<Offer>>((ref) => ref.watch(offersRepositoryProvider).mine());

final negotiationsProvider =
    FutureProvider<List<Offer>>((ref) => ref.watch(offersRepositoryProvider).negotiations());
