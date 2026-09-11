import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A small (i) button next to a password field that explains the rules in
/// plain bullet points — tap to open, since a hover-only Tooltip isn't
/// reliably discoverable on a touchscreen.
class PasswordRequirementsInfo extends StatelessWidget {
  const PasswordRequirementsInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      icon: const Icon(Icons.info_outline, size: 20),
      tooltip: l10n.passwordRequirementsTitle,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.passwordRequirementsTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bullet(l10n.passwordRequirementLength),
              _Bullet(l10n.passwordRequirementAlphanumeric),
              _Bullet(l10n.passwordRequirementSpecialAllowed),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.actionClose),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
