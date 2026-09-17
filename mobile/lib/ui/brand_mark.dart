import 'package:flutter/material.dart';

/// The logo mark (the two-shape "h") next to the "Hiww" wordmark, dot in
/// the brand coral. The mark image is theme-aware — see tool/gen_icon.dart
/// for how assets/images/hiww_mark[_dark].png are derived from the source
/// logo art in assets/icon/logo_source.png.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.fontSize = 22, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = color ?? scheme.onSurface;
    final markAsset = Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/hiww_mark_dark.png'
        : 'assets/images/hiww_mark.png';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(markAsset, height: fontSize, filterQuality: FilterQuality.medium),
        SizedBox(width: fontSize * 0.22),
        Text.rich(
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
        ),
      ],
    );
  }
}
