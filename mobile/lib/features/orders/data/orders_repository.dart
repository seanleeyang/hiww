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
  Future<void> markShipped(String id) =>
      _api.post('/api/orders/$id/deliver', body: {'note': 'Shipped'});
  Future<void> confirmReceived(String id) =>
      _api.post('/api/orders/$id/release', body: {'note': 'Received'});
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
