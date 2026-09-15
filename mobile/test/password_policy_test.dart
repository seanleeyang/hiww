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

  group('PasswordPolicy.meetsAllRequirements', () {
    test('rejects a password that meets only the backend minimum', () {
      // Passes meetsMinimum (length, a letter, a digit) but has neither a
      // symbol nor mixed case — the checklist's stricter, client-side bar.
      expect(PasswordPolicy.meetsMinimum('letters123'), isTrue);
      expect(PasswordPolicy.meetsAllRequirements('letters123'), isFalse);
    });

    test('rejects missing a symbol', () {
      expect(PasswordPolicy.meetsAllRequirements('Letters123'), isFalse);
    });

    test('rejects missing mixed case', () {
      expect(PasswordPolicy.meetsAllRequirements('letters123!'), isFalse);
    });

    test('rejects under 8 characters even with every other rule met', () {
      expect(PasswordPolicy.meetsAllRequirements('Ab1!'), isFalse);
    });

    test('accepts length + digit + symbol + mixed case', () {
      expect(PasswordPolicy.meetsAllRequirements('Letters123!'), isTrue);
    });

    test('is always a superset of meetsMinimum', () {
      const candidates = ['Letters123!', 'letters123', '12345678', 'ALLUPPER1!', ''];
      for (final v in candidates) {
        if (PasswordPolicy.meetsAllRequirements(v)) {
          expect(PasswordPolicy.meetsMinimum(v), isTrue, reason: 'failed for "$v"');
        }
      }
    });
  });
}
