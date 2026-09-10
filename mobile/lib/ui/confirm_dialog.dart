import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The one confirm-dialog shape the whole app uses — a centered title, a
/// body (plain text or a custom widget, e.g. a price breakdown), and a
/// full-width stacked confirm/cancel pair, confirm on top. Consistent button
/// placement means "which side is destructive" stays muscle memory across
/// every screen instead of resetting each time. Always shadows the
/// builder's own `context` for the pop, never the caller's — these dialogs
/// are opened from pages that live inside the bottom-tab shell's nested
/// navigator, not the root one; popping with the caller's context would pop
/// the tab's own page instead of just dismissing the dialog.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required Widget body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: body,
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
                  : null,
              onPressed: () => context.pop(true),
              child: Text(confirmLabel),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.pop(false), child: Text(cancelLabel)),
          ],
        ),
      ],
    ),
  );
  return ok == true;
}

/// "Remove from list" dialog for a cancelled/completed want or trip card.
Future<bool> showRemoveFromListDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
}) {
  return showConfirmDialog(
    context,
    title: title,
    body: Text(body),
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    destructive: true,
  );
}

/// "Cancel this trip/want" dialog.
Future<bool> showCancelConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String keepLabel,
  required String confirmLabel,
}) {
  return showConfirmDialog(
    context,
    title: title,
    body: Text(body),
    confirmLabel: confirmLabel,
    cancelLabel: keepLabel,
    destructive: true,
  );
}
