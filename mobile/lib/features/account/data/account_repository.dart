import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  Future<void> submitKyc({
    required String documentType,
    required String documentId,
    required String firstName,
    required String lastName,
    required String address,
    required String contactNumber,
    required String documentPhotoUrl,
    required String selfiePhotoUrl,
    String? documentPhotoBackUrl,
  }) async {
    final body = <String, dynamic>{
      'document_type': documentType,
      'document_id': documentId,
      'first_name': firstName,
      'last_name': lastName,
      'address': address,
      'contact_number': contactNumber,
      'document_photo_url': documentPhotoUrl,
      'selfie_photo_url': selfiePhotoUrl,
    };
    if (documentPhotoBackUrl != null) body['document_photo_back_url'] = documentPhotoBackUrl;
    await _api.post('/api/compliance/kyc/submit', body: body);
  }

  Future<void> updateProfile({
    String? fullName,
    String? homeCity,
    String? avatarUrl,
    String? email,
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
    if (email != null) body['email'] = email;
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
