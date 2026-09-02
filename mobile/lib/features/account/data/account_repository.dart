import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  Future<void> submitKyc({
    required String documentType,
    required String documentId,
  }) async {
    await _api.post('/api/compliance/kyc/submit', body: {
      'document_type': documentType,
      'document_id': documentId,
    });
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(apiClientProvider)),
);
