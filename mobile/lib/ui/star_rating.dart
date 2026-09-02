import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Read-only row of stars with an optional trailing label ("4.9 · 147 delivered").
class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.count,
    this.trailing,
    this.size = 14,
  });

  final double rating;
  final int? count;
  final String? trailing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final star = context.hiww.star;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size + 2, color: star),
        const SizedBox(width: 3),
        Text(
          rating > 0 ? rating.toStringAsFixed(1) : 'New',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: size),
        ),
        if (trailing != null) ...[
          Text('  ·  $trailing',
              style: TextStyle(color: muted, fontSize: size)),
        ] else if (count != null && count! > 0) ...[
          Text('  ·  $count', style: TextStyle(color: muted, fontSize: size)),
        ],
      ],
    );
  }
}

/// Tappable 1–5 star input.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 40,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final star = context.hiww.star;
    final idle = Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () => onChanged(i),
            iconSize: size,
            tooltip: '$i star${i == 1 ? '' : 's'}',
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i <= value ? star : idle,
            ),
          ),
      ],
    );
  }
}
