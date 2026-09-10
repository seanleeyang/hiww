import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/order.dart';

class OrdersRepository {
  OrdersRepository(this._api);
  final ApiClient _api;

  Future<Order> byId(String id) async {
    final data = await _api.get('/api/orders/$id');
    return Order.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<Order>> mine() async {
    final data = await _api.get('/api/orders');
    final items = ((data as Map)['items'] as List?) ?? [];
    return items.map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> claimPayment(String id) => _api.post('/api/orders/$id/claim-payment');

  /// [itemPhotoUrl] is optional so old call sites (and any future
  /// admin/test-lab shortcut) that only have a receipt keep working.
  Future<void> submitPurchaseProof(
    String id, {
    required String receiptImageUrl,
    String? itemPhotoUrl,
  }) =>
      _api.post('/api/orders/$id/purchase-proof', body: {
        'image_url': receiptImageUrl,
        'item_photo_url': ?itemPhotoUrl,
      });
  /// [shippingProofUrl] is optional — a photo with the courier or a
  /// screenshot of the delivery app's booking page. Marking shipped still
  /// works without it.
  Future<void> markShipped(String id, {String? shippingProofUrl}) =>
      _api.post('/api/orders/$id/deliver', body: {
        'note': 'Shipped',
        'shipping_proof_url': ?shippingProofUrl,
      });
  Future<void> confirmReceived(String id) =>
      _api.post('/api/orders/$id/release', body: {'note': 'Received'});

  /// Adds or replaces shipping proof after the order has already shipped —
  /// the picker at ship-time is a one-shot opportunity; this covers a
  /// traveler who skipped it then, or wants to swap in a better photo.
  Future<void> addShippingProof(String id, String imageUrl) =>
      _api.post('/api/orders/$id/shipping-proof', body: {'image_url': imageUrl});
}

final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepository(ref.watch(apiClientProvider)),
);

final orderProvider = FutureProvider.family<Order, String>(
  (ref, id) => ref.watch(ordersRepositoryProvider).byId(id),
);

final myOrdersProvider =
    FutureProvider<List<Order>>((ref) => ref.watch(ordersRepositoryProvider).mine());

/// request id -> order id, for linking an accepted want to its order.
final orderIdByRequestProvider = FutureProvider<Map<String, String>>((ref) async {
  final orders = await ref.watch(myOrdersProvider.future);
  return {
    for (final o in orders)
      if (o.requestId != null) o.requestId!: o.id,
  };
});
