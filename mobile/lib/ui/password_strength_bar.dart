import 'package:flutter/material.dart';

import '../core/password_policy.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Four-segment strength meter shown under a password field as the user
/// types. Hidden entirely while the field is empty — nothing to judge yet.
class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = PasswordPolicy.strengthOf(password);
    if (strength == PasswordStrength.empty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final success = context.hiww.success;

    final (String label, int level, Color color) = switch (strength) {
      PasswordStrength.weak => (l10n.passwordStrengthWeak, 1, scheme.error),
      PasswordStrength.fair => (l10n.passwordStrengthFair, 2, scheme.tertiary),
      PasswordStrength.good => (
          l10n.passwordStrengthGood,
          3,
          Color.lerp(scheme.tertiary, success, 0.6)!,
        ),
      PasswordStrength.strong => (l10n.passwordStrengthStrong, 4, success),
      PasswordStrength.empty => ('', 0, scheme.outlineVariant),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (i) {
              final filled = i < level;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: filled ? color : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
