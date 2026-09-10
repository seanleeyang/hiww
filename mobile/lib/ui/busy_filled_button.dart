import 'package:flutter/material.dart';

/// A [FilledButton] that swaps its label for a small spinner while [busy],
/// and disables itself so a slow request can't be double-submitted.
class BusyFilledButton extends StatelessWidget {
  const BusyFilledButton({
    super.key,
    required this.busy,
    required this.label,
    required this.onPressed,
    this.spinnerSize = 20,
  });

  final bool busy;
  final String label;
  final VoidCallback? onPressed;

  /// Most call sites use the default 20x20; a couple of tighter buttons use
  /// 18 to match a smaller button height.
  final double spinnerSize;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? SizedBox(
              height: spinnerSize,
              width: spinnerSize,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
