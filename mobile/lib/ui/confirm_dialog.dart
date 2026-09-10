import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// "Remove from list" dialog for a cancelled/completed want or trip card —
/// destructive [FilledButton] stacked above an [OutlinedButton] cancel, both
/// inside the dialog content. Always shadows the builder's own `context` for
/// the pop, never the caller's — these dialogs are opened from pages that
/// live inside the bottom-tab shell's nested navigator, not the root one;
/// popping with the caller's context would pop the tab's own page instead of
/// just dismissing the dialog.
Future<bool> showRemoveFromListDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(body),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => context.pop(true),
            child: Text(confirmLabel),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => context.pop(false), child: Text(cancelLabel)),
        ],
      ),
    ),
  );
  return ok == true;
}

/// "Cancel this trip/want" dialog — a standard horizontal actions row, keep
/// on the left and a destructive confirm on the right. Same context-shadowing
/// rule as [showRemoveFromListDialog].
Future<bool> showCancelConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String keepLabel,
  required String confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => context.pop(false), child: Text(keepLabel)),
        FilledButton(
          onPressed: () => context.pop(true),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}
