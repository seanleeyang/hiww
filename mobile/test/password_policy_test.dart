import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/core/password_policy.dart';

void main() {
  group('PasswordPolicy.meetsMinimum', () {
    test('rejects under 8 characters', () {
      expect(PasswordPolicy.meetsMinimum('abc123'), isFalse);
    });

    test('rejects letters only', () {
      expect(PasswordPolicy.meetsMinimum('alllettersnodigits'), isFalse);
    });

    test('rejects digits only', () {
      expect(PasswordPolicy.meetsMinimum('12345678'), isFalse);
    });

    test('rejects over 128 characters', () {
      expect(PasswordPolicy.meetsMinimum('a1${'x' * 128}'), isFalse);
    });

    test('accepts letters + digits, special characters not required', () {
      expect(PasswordPolicy.meetsMinimum('letters123'), isTrue);
    });

    test('accepts letters + digits + special characters', () {
      expect(PasswordPolicy.meetsMinimum('SecurePass123!'), isTrue);
    });
  });

  group('PasswordPolicy.strengthOf', () {
    test('empty password has no strength', () {
      expect(PasswordPolicy.strengthOf(''), PasswordStrength.empty);
    });

    test('a short simple password is weak', () {
      expect(PasswordPolicy.strengthOf('abc123'), PasswordStrength.weak);
    });

    test('length + digit only is fair or better, never weak', () {
      expect(PasswordPolicy.strengthOf('lowercase123'), isNot(PasswordStrength.weak));
    });

    test('long, mixed-case, digits and symbols scores strong', () {
      expect(PasswordPolicy.strengthOf('Sup3r-Str0ng_Passphrase!'), PasswordStrength.strong);
    });

    test('longer is never weaker than shorter, all else equal', () {
      final shortScore = PasswordPolicy.strengthOf('Abc123!').index;
      final longerScore = PasswordPolicy.strengthOf('Abc123!Abc123!Abc123!').index;
      expect(longerScore, greaterThanOrEqualTo(shortScore));
    });
  });
}
