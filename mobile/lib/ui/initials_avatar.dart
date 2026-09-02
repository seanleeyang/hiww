import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';

const _palette = <Color>[
  Color(0xFFE1523A),
  Color(0xFF2E9E6B),
  Color(0xFF2B6CB0),
  Color(0xFF6B46C1),
  Color(0xFFB7791F),
  Color(0xFF0D7D7D),
];

/// Circular avatar: the user's photo when [url] is set, otherwise a coloured
/// disc with their initials (colour is stable per name).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.url, this.radius = 20});

  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.hashCode.abs() % _palette.length];
    final hasUrl = url != null && url!.startsWith('http');

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.16),
      foregroundImage:
          hasUrl ? CachedNetworkImageProvider(url!) : null,
      child: hasUrl
          ? null
          : Text(
              initials(name),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}
