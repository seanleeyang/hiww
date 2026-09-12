import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/offer.dart';
import '../domain/want.dart';

class WantsRepository {
  WantsRepository(this._api);
  final ApiClient _api;

  /// Pass [targetTripId] for "Request from this trip" — the want is sent
  /// directly and privately to that trip's traveler (never shown in public
  /// browse) and immediately opens a negotiation at [budget].
  Future<String> create({
    required String title,
    required String itemDescription,
    required String sourceCountry,
    String? sourceCity,
    required String category,
    required double estimatedWeightKg,
    required String budget,
    int quantity = 1,
    DateTime? needBy,
    String? imageUrl,
    String? targetTripId,
    required String destinationCountry,
    String? destinationCity,
    String? productUrl,
    // Delivery address (migration 045). Defaults to true server-side too, so
    // omitting these entirely still works — see createRequestSchema.
    bool? deliverySameAsRegistered,
    String? deliveryAddressStreet,
    String? deliveryAddressStreet2,
    String? deliveryAddressSubdistrict,
    String? deliveryAddressDistrict,
    String? deliveryAddressPostalCode,
  }) async {
    final body = <String, dynamic>{
      'item_description': itemDescription,
      'source_country': sourceCountry,
      'category': category,
      'estimated_weight_kg': estimatedWeightKg,
      'budget': budget,
      'quantity': quantity,
      'title': title,
      'destination_country': destinationCountry,
    };
    if (sourceCity != null && sourceCity.isNotEmpty) body['source_city'] = sourceCity;
    if (needBy != null) body['need_by'] = needBy.toUtc().toIso8601String();
    if (imageUrl != null && imageUrl.isNotEmpty) body['image_url'] = imageUrl;
    if (targetTripId != null) body['target_trip_id'] = targetTripId;
    if (destinationCity != null && destinationCity.isNotEmpty) {
      body['destination_city'] = destinationCity;
    }
    if (productUrl != null && productUrl.isNotEmpty) body['product_url'] = productUrl;
    if (deliverySameAsRegistered != null) {
      body['delivery_same_as_registered'] = deliverySameAsRegistered;
    }
    if (deliveryAddressStreet != null && deliveryAddressStreet.isNotEmpty) {
      body['delivery_address_street'] = deliveryAddressStreet;
    }
    if (deliveryAddressStreet2 != null && deliveryAddressStreet2.isNotEmpty) {
      body['delivery_address_street2'] = deliveryAddressStreet2;
    }
    if (deliveryAddressSubdistrict != null && deliveryAddressSubdistrict.isNotEmpty) {
      body['delivery_address_subdistrict'] = deliveryAddressSubdistrict;
    }
    if (deliveryAddressDistrict != null && deliveryAddressDistrict.isNotEmpty) {
      body['delivery_address_district'] = deliveryAddressDistrict;
    }
    if (deliveryAddressPostalCode != null && deliveryAddressPostalCode.isNotEmpty) {
      body['delivery_address_postal_code'] = deliveryAddressPostalCode;
    }
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

  Future<void> update(
    String id, {
    String? title,
    String? itemDescription,
    String? sourceCity,
    String? category,
    double? estimatedWeightKg,
    String? budget,
    int? quantity,
    DateTime? needBy,
    String? imageUrl,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (itemDescription != null) body['item_description'] = itemDescription;
    if (sourceCity != null) body['source_city'] = sourceCity;
    if (category != null) body['category'] = category;
    if (estimatedWeightKg != null) body['estimated_weight_kg'] = estimatedWeightKg;
    if (budget != null) body['budget'] = budget;
    if (quantity != null) body['quantity'] = quantity;
    if (needBy != null) body['need_by'] = needBy.toUtc().toIso8601String();
    if (imageUrl != null) body['image_url'] = imageUrl;
    await _api.patch('/api/requests/$id', body: body);
  }

  Future<void> cancel(String id) => _api.post('/api/requests/$id/cancel');

  /// Clears a cancelled/completed want from My Wants — doesn't touch the
  /// row or its history, just hides it from [mine].
  Future<void> archive(String id) => _api.post('/api/requests/$id/archive');
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
