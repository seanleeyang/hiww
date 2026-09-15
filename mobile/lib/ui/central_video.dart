import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

/// A muted, looping video used as [FloatingOrbitIllustration]'s central
/// object in place of the Lottie/icon placeholders, for slides whose
/// illustration was delivered as a rendered clip rather than vector data.
///
/// Rendered inside a rounded card with a border and shadow, rather than
/// edge-to-edge: source videos here are plain .mp4 (no alpha channel), so
/// there's no way to make an arbitrary background transparent — every
/// export attempt just changes *which* solid rectangle shows up behind the
/// subject (white, black, gray, even a literal checkerboard once, baked in
/// as real pixels by an export tool's "transparent" preview indicator).
/// Framing it as a deliberate photo card sidesteps that entirely: the
/// rectangle becomes the point instead of a bug, and it uses the theme's
/// own surface/outline/shadow tokens, so it's correct in dark mode too
/// (an edge-to-edge video never could be, without real alpha).
class CentralVideo extends StatefulWidget {
  const CentralVideo({super.key, required this.asset, required this.size});

  final String asset;
  final double size;

  @override
  State<CentralVideo> createState() => _CentralVideoState();
}

class _CentralVideoState extends State<CentralVideo> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.asset)
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _controller.play();
      }).catchError((_) {
        // Stay on the placeholder SizedBox rather than crash the onboarding
        // screen over a bad/unsupported video asset.
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(HiwwRadii.card),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _controller.value.isInitialized
          ? ClipRRect(
              borderRadius: BorderRadius.circular(HiwwRadii.card),
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : null,
    );
  }
}
