import 'package:flutter/material.dart';

/// The "Hiww" wordmark with the dot in the brand coral.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.fontSize = 22, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = color ?? scheme.onSurface;
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: ink,
        ),
        children: [
          const TextSpan(text: 'Hiww'),
          TextSpan(text: '.', style: TextStyle(color: scheme.primary)),
        ],
      ),
    );
  }
}
