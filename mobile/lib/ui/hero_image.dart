import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A rounded image that takes a user-supplied URL and falls back to a bundled
/// asset. Shows a tinted box while a network image loads or if it fails.
class HeroImage extends StatelessWidget {
  const HeroImage({
    super.key,
    this.url,
    required this.fallbackAsset,
    this.height = 168,
    this.borderRadius = 16,
  });

  final String? url;
  final String fallbackAsset;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final placeholder = Container(color: Theme.of(context).colorScheme.surfaceContainerHigh);
    final hasUrl = url != null && url!.startsWith('http');

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: hasUrl
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) =>
                    Image.asset(fallbackAsset, fit: BoxFit.cover),
              )
            : Image.asset(fallbackAsset, fit: BoxFit.cover),
      ),
    );
  }
}
