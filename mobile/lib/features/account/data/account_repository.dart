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
    required String documentPhotoUrl,
    required String selfiePhotoUrl,
  }) async {
    final body = <String, dynamic>{
      'document_type': documentType,
      'document_id': documentId,
      'first_name': firstName,
      'last_name': lastName,
      'address': address,
      'document_photo_url': documentPhotoUrl,
      'selfie_photo_url': selfiePhotoUrl,
    };
    await _api.post('/api/compliance/kyc/submit', body: body);
  }

  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? email,
    String? phone,
    String? gender,
    String? dateOfBirth,
    String? addressStreet,
    String? addressStreet2,
    String? addressDistrict,
    String? addressSubdistrict,
    String? addressCity,
    String? addressPostalCode,
    String? addressCountry,
    String? bankName,
    String? bankAccountNumber,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl.isEmpty ? null : avatarUrl;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone.isEmpty ? null : phone;
    if (gender != null) body['gender'] = gender.isEmpty ? null : gender;
    if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth.isEmpty ? null : dateOfBirth;
    if (addressStreet != null) body['address_street'] = addressStreet.isEmpty ? null : addressStreet;
    if (addressStreet2 != null) {
      body['address_street2'] = addressStreet2.isEmpty ? null : addressStreet2;
    }
    if (addressDistrict != null) {
      body['address_district'] = addressDistrict.isEmpty ? null : addressDistrict;
    }
    if (addressSubdistrict != null) {
      body['address_subdistrict'] = addressSubdistrict.isEmpty ? null : addressSubdistrict;
    }
    if (addressCity != null) body['address_city'] = addressCity.isEmpty ? null : addressCity;
    if (addressPostalCode != null) {
      body['address_postal_code'] = addressPostalCode.isEmpty ? null : addressPostalCode;
    }
    if (addressCountry != null) body['address_country'] = addressCountry.isEmpty ? null : addressCountry;
    if (bankName != null) body['bank_name'] = bankName.isEmpty ? null : bankName;
    if (bankAccountNumber != null) {
      body['bank_account_number'] = bankAccountNumber.isEmpty ? null : bankAccountNumber;
    }
    await _api.patch('/api/me', body: body);
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(apiClientProvider)),
);
