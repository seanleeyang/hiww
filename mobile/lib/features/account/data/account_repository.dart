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
    String? bio,
    String? phone,
    String? addressStreet,
    String? addressCity,
    String? addressPostalCode,
    String? addressCountry,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (homeCity != null) body['home_city'] = homeCity.isEmpty ? null : homeCity;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl.isEmpty ? null : avatarUrl;
    if (bio != null) body['bio'] = bio.isEmpty ? null : bio;
    if (phone != null) body['phone'] = phone.isEmpty ? null : phone;
    if (addressStreet != null) body['address_street'] = addressStreet.isEmpty ? null : addressStreet;
    if (addressCity != null) body['address_city'] = addressCity.isEmpty ? null : addressCity;
    if (addressPostalCode != null) {
      body['address_postal_code'] = addressPostalCode.isEmpty ? null : addressPostalCode;
    }
    if (addressCountry != null) body['address_country'] = addressCountry.isEmpty ? null : addressCountry;
    await _api.patch('/api/me', body: body);
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(apiClientProvider)),
);
