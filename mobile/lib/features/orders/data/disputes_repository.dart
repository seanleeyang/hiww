import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class DisputesRepository {
  DisputesRepository(this._api);
  final ApiClient _api;

  Future<void> open(String orderId, String reason) =>
      _api.post('/api/disputes', body: {'order_id': orderId, 'reason': reason});
}

final disputesRepositoryProvider = Provider<DisputesRepository>(
  (ref) => DisputesRepository(ref.watch(apiClientProvider)),
);
