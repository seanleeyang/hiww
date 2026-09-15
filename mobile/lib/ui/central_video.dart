import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A muted, looping video used as [FloatingOrbitIllustration]'s central
/// object in place of the Lottie/icon placeholders, for slides whose
/// illustration was delivered as a rendered clip rather than vector data.
/// No alpha channel — the source video's own background must already match
/// the screen background it's placed on (see the onboarding/landing Linen
/// background, #FFEDE3) for it to read as a floating object rather than a
/// visible rectangle; it will show that rectangle in dark mode, where the
/// background is different.
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
    if (!_controller.value.isInitialized) {
      return SizedBox(width: widget.size, height: widget.size);
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}
