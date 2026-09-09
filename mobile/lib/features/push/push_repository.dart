import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

/// Registers/unregisters this device's FCM token with the backend so it can
/// be targeted by a push (see `src/services/push/` and
/// `src/modules/devices/routes.ts`). A user can have several registered
/// devices at once; each token is upserted independently.
class PushRepository {
  PushRepository(this._api);
  final ApiClient _api;

  Future<void> registerToken({required String token, required String platform}) =>
      _api.post('/api/devices/register', body: {'token': token, 'platform': platform});

  Future<void> unregisterToken(String token) =>
      _api.post('/api/devices/unregister', body: {'token': token});
}

final pushRepositoryProvider = Provider<PushRepository>(
  (ref) => PushRepository(ref.watch(apiClientProvider)),
);
