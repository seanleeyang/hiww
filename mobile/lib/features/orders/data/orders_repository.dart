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
