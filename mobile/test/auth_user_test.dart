import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/features/auth/domain/auth_user.dart';

void main() {
  test('parses a full /api/me payload', () {
    final user = AuthUser.fromJson({
      'id': 'u1',
      'email': 'a@b.com',
      'full_name': 'Ada Lovelace',
      'user_type': 'both',
      'role': 'user',
      'kyc_status': 'approved',
      'risk_status': 'clear',
      'avatar_url': 'https://img/x.png',
      'home_city': 'Bangkok',
      'rating_avg': 4.7,
      'rating_count': 12,
      'delivered_count': 9,
      'pilot': {'manual_money': true, 'payment_instructions': 'PromptPay ...'},
      'gender': 'female',
      'date_of_birth': '1990-01-15T00:00:00.000Z',
      'address_street2': 'Unit 4B',
      'address_district': 'Watthana',
      'address_subdistrict': 'Khlong Toei Nuea',
    });

    expect(user.firstName, 'Ada');
    expect(user.userType.isShopper, true);
    expect(user.userType.isTraveler, true);
    expect(user.isKycApproved, true);
    expect(user.avatarUrl, 'https://img/x.png');
    expect(user.ratingAvg, 4.7);
    expect(user.deliveredCount, 9);
    expect(user.pilot!.manualMoney, true);
    expect(user.gender, 'female');
    expect(user.dateOfBirth, '1990-01-15');
    expect(user.addressStreet2, 'Unit 4B');
    expect(user.addressDistrict, 'Watthana');
    expect(user.addressSubdistrict, 'Khlong Toei Nuea');
  });

  test('tolerates a minimal payload (pre-D2 backend)', () {
    final user = AuthUser.fromJson({
      'id': 'u2',
      'email': 'x@y.com',
      'full_name': 'Sam',
      'user_type': 'shopper',
      'role': 'user',
      'kyc_status': 'pending',
      'risk_status': 'clear',
    });

    expect(user.avatarUrl, isNull);
    expect(user.ratingAvg, 0);
    expect(user.deliveredCount, 0);
    expect(user.userType.isTraveler, false);
  });
}
