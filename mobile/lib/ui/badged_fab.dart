import 'package:flutter/material.dart';

/// A [FloatingActionButton] with a small "+" badge pinned to the button's
/// own outer corner — positioned outside the main icon's bounding box, so
/// it can never visually overlap the icon itself regardless of the icon's
/// shape (e.g. a diagonal plane glyph).
class BadgedFab extends StatelessWidget {
  const BadgedFab({super.key, required this.icon, required this.onPressed, required this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;

  /// What this FAB does, e.g. "Post a trip" — read by screen readers and
  /// shown on long-press, same as every other icon-only control in the app.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 24),
          Positioned(
            right: -5,
            top: -5,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.primaryContainer, width: 1.5),
              ),
              child: Icon(Icons.add, size: 9, color: scheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
