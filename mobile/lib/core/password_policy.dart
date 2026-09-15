import '../l10n/app_localizations.dart';

/// Shared password rules — mirrors `src/types/schemas.ts`'s `passwordSchema`
/// on the backend exactly, so the form can reject a weak password before
/// ever making a network call. Applied anywhere a password is being *set*
/// (register, reset, change) — never to login, since an existing account's
/// password may predate this policy.
class PasswordPolicy {
  static const minLength = 8;
  static const maxLength = 128;

  static bool _hasLetter(String v) => RegExp(r'[a-zA-Z]').hasMatch(v);

  /// Individually-named rules — public because [PasswordRequirementsChecklist]
  /// evaluates each one live, per keystroke, to flip its own row.
  static bool hasMinLength(String v) => v.length >= minLength && v.length <= maxLength;
  static bool hasDigit(String v) => RegExp(r'[0-9]').hasMatch(v);
  static bool hasMixedCase(String v) =>
      RegExp(r'[a-z]').hasMatch(v) && RegExp(r'[A-Z]').hasMatch(v);
  static bool hasSymbol(String v) => RegExp(r'[^a-zA-Z0-9]').hasMatch(v);

  static bool meetsMinimum(String v) =>
      v.length >= minLength && v.length <= maxLength && _hasLetter(v) && hasDigit(v);

  /// Stricter than [meetsMinimum] (which mirrors the backend's actual floor)
  /// — this is the client-side bar the checklist and its submit-button gate
  /// enforce. Always a superset of [meetsMinimum], so nothing that clears
  /// this can ever be rejected by the backend.
  static bool meetsAllRequirements(String v) =>
      hasMinLength(v) && hasDigit(v) && hasSymbol(v) && hasMixedCase(v);

  static PasswordStrength strengthOf(String v) {
    if (v.isEmpty) return PasswordStrength.empty;
    var score = 0;
    if (v.length >= minLength) score++;
    if (v.length >= 12) score++;
    if (v.length >= 16) score++;
    if (hasMixedCase(v)) score++;
    if (hasDigit(v)) score++;
    if (hasSymbol(v)) score++;

    if (score <= 1) return PasswordStrength.weak;
    if (score <= 3) return PasswordStrength.fair;
    if (score <= 4) return PasswordStrength.good;
    return PasswordStrength.strong;
  }
}

enum PasswordStrength { empty, weak, fair, good, strong }

/// Shared field validator for anywhere a password is being *set* — matches
/// [PasswordPolicy.meetsMinimum] exactly so the message always corresponds
/// to why validation actually failed.
String? validateNewPassword(String? v, AppLocalizations l10n) {
  final value = v ?? '';
  if (value.length < PasswordPolicy.minLength) return l10n.errorPasswordTooShort;
  if (value.length > PasswordPolicy.maxLength) return l10n.errorPasswordTooLong;
  if (!RegExp(r'[a-zA-Z]').hasMatch(value) || !RegExp(r'[0-9]').hasMatch(value)) {
    return l10n.errorPasswordNotAlphanumeric;
  }
  return null;
}
