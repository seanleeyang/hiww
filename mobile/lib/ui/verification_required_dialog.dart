import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

bool _showing = false;
DateTime? _lastDismissedAt;
const _cooldown = Duration(seconds: 30);

/// Shown whenever a gated action 403s with VERIFICATION_REQUIRED (see
/// ApiClient's error mapping) — a friendlier prompt than a raw error, matching
/// a "Before You Proceed" pattern. Continue takes them to `/verify`; Cancel
/// just dismisses and lets them keep browsing (most actions will keep 403ing
/// until they actually verify, same as today).
///
/// Two guards keep this from nagging: it never shows while already on
/// `/verify` (the whole point of Continue is to get there — showing it again
/// once arrived is pointless and was happening because background polling —
/// the unread chat/notification badge counts, unscoped to any particular
/// screen — hits the same gated check every 15-20s regardless of where the
/// user is), and it won't re-show within [_cooldown] of the last dismissal
/// for the same reason (Cancel felt broken when the very next poll popped it
/// right back up).
Future<void> showVerificationRequiredDialog(BuildContext context) async {
  if (_showing) return;
  final onVerifyScreen =
      GoRouter.of(context).routerDelegate.currentConfiguration.uri.path == '/verify';
  if (onVerifyScreen) return;
  final lastDismissed = _lastDismissedAt;
  if (lastDismissed != null && DateTime.now().difference(lastDismissed) < _cooldown) return;
  _showing = true;
  try {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified_user_outlined, size: 40),
        title: Text(l10n.verifyGateTitle, textAlign: TextAlign.center),
        content: Text(l10n.verifyGateBody, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              context.pop();
              context.push('/verify');
            },
            child: Text(l10n.actionContinue),
          ),
          TextButton(
            onPressed: () => context.pop(),
            child: Text(l10n.actionCancel),
          ),
        ],
      ),
    );
  } finally {
    _showing = false;
    _lastDismissedAt = DateTime.now();
  }
}
