import 'package:flutter/material.dart';

import '../core/password_policy.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Live checklist shown under a new-password field: each row flips from a
/// muted dot to a green check the moment its rule passes. Read
/// [PasswordPolicy.meetsAllRequirements] (all four rows true) to decide
/// whether a submit button should be enabled.
class PasswordRequirementsChecklist extends StatelessWidget {
  const PasswordRequirementsChecklist({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = <(String, bool)>[
      (l10n.passwordRuleLength, PasswordPolicy.hasMinLength(password)),
      (l10n.passwordRuleNumber, PasswordPolicy.hasDigit(password)),
      (l10n.passwordRuleSymbol, PasswordPolicy.hasSymbol(password)),
      (l10n.passwordRuleMixedCase, PasswordPolicy.hasMixedCase(password)),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, passed) in rows) _RuleRow(label: label, passed: passed),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.passed});

  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final success = context.hiww.success;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: passed
                ? Icon(Icons.check_circle, size: 16, color: success)
                : Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: muted, shape: BoxShape.circle),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: passed ? Theme.of(context).colorScheme.onSurface : muted,
            ),
          ),
        ],
      ),
    );
  }
}
