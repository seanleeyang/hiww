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

  Future<void> updateProfile({
    String? fullName,
    String? homeCity,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (homeCity != null) body['home_city'] = homeCity.isEmpty ? null : homeCity;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl.isEmpty ? null : avatarUrl;
    await _api.patch('/api/me', body: body);
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(apiClientProvider)),
);
