import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A muted, looping video used as [FloatingOrbitIllustration]'s central
/// object in place of the Lottie/icon placeholders, for slides whose
/// illustration was delivered as a rendered clip rather than vector data.
///
/// Rendered edge-to-edge, directly on the screen background — the source
/// video's own background is a close match to the app's Linen
/// (assets/video/piggy_bank.mp4, ~RGB(250,232,221) vs Linen's
/// RGB(255,237,227)), close enough that it reads as the subject floating
/// rather than a visible box, without needing a card frame around it. (A
/// card frame was used briefly when the render didn't match; see git
/// history if a future video needs it again — chroma-key transparency was
/// also tried and ruled out, see the removed doc comment in that commit.)
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
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}
