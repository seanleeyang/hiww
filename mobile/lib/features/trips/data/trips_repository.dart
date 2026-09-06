import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/trip.dart';

class TripsRepository {
  TripsRepository(this._api);
  final ApiClient _api;

  Future<String> create({
    required String departureCountry,
    required String arrivalCountry,
    String? departureCity,
    String? arrivalCity,
    required DateTime departureDate,
    required DateTime returnDate,
    required double maxWeightKg,
    required int maxItems,
    String? title,
    String? note,
    String? coverImageUrl,
  }) async {
    final body = <String, dynamic>{
      'departure_country': departureCountry,
      'arrival_country': arrivalCountry,
      'departure_date': departureDate.toUtc().toIso8601String(),
      'return_date': returnDate.toUtc().toIso8601String(),
      'max_weight_kg': maxWeightKg,
      'max_items': maxItems,
    };
    if (departureCity?.isNotEmpty ?? false) body['departure_city'] = departureCity;
    if (arrivalCity?.isNotEmpty ?? false) body['arrival_city'] = arrivalCity;
    if (title?.isNotEmpty ?? false) body['title'] = title;
    if (note?.isNotEmpty ?? false) body['note'] = note;
    if (coverImageUrl?.isNotEmpty ?? false) body['cover_image_url'] = coverImageUrl;
    final data = await _api.post('/api/trips', body: body);
    return (data as Map)['id'].toString();
  }

  Future<List<Trip>> mine() async {
    final data = await _api.get('/api/trips/mine');
    final items = ((data as Map)['items'] as List?) ?? [];
    return items.map((e) => Trip.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<TripDetail> byId(String id) async {
    final data = await _api.get('/api/trips/$id');
    return TripDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> update(
    String id, {
    String? departureCity,
    String? arrivalCity,
    DateTime? departureDate,
    DateTime? returnDate,
    double? maxWeightKg,
    int? maxItems,
    String? title,
    String? note,
    String? coverImageUrl,
  }) async {
    final body = <String, dynamic>{};
    if (departureCity != null) body['departure_city'] = departureCity;
    if (arrivalCity != null) body['arrival_city'] = arrivalCity;
    if (departureDate != null) body['departure_date'] = departureDate.toUtc().toIso8601String();
    if (returnDate != null) body['return_date'] = returnDate.toUtc().toIso8601String();
    if (maxWeightKg != null) body['max_weight_kg'] = maxWeightKg;
    if (maxItems != null) body['max_items'] = maxItems;
    if (title != null) body['title'] = title;
    if (note != null) body['note'] = note;
    if (coverImageUrl != null) body['cover_image_url'] = coverImageUrl;
    await _api.patch('/api/trips/$id', body: body);
  }

  Future<void> cancel(String id) => _api.post('/api/trips/$id/cancel');

  /// A real delete — only allowed while the trip has zero offers, even
  /// pending ones. Use [cancel] once there's any activity on it.
  Future<void> delete(String id) => _api.delete('/api/trips/$id');
}

final tripsRepositoryProvider = Provider<TripsRepository>(
  (ref) => TripsRepository(ref.watch(apiClientProvider)),
);

final myTripsProvider =
    FutureProvider<List<Trip>>((ref) => ref.watch(tripsRepositoryProvider).mine());

/// Only published trips — used to pick a trip when making an offer.
final myPublishedTripsProvider = FutureProvider<List<Trip>>((ref) async {
  final trips = await ref.watch(tripsRepositoryProvider).mine();
  return trips.where((t) => t.status == 'published').toList();
});

final tripDetailProvider = FutureProvider.family<TripDetail, String>(
  (ref, id) => ref.watch(tripsRepositoryProvider).byId(id),
);
