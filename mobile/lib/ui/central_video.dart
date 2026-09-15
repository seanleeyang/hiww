import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A muted, looping video, sized by whatever box the caller places it in
/// (wrap with an `AspectRatio`/`SizedBox` — it doesn't size itself) —
/// rendered edge-to-edge, directly on the screen background rather than in
/// a card. The source video's own background is a close match to the app's
/// Linen (assets/video/piggy_bank.mp4, ~RGB(250,232,221) vs Linen's
/// RGB(255,237,227)), close enough that it reads as the subject floating
/// rather than a visible box. (A card frame was used briefly when the
/// render didn't match; see git history if a future video needs it again —
/// chroma-key transparency was also tried and ruled out, see the removed
/// doc comment in that commit.)
class CentralVideo extends StatefulWidget {
  const CentralVideo({super.key, required this.asset});

  final String asset;

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
      return const SizedBox.expand();
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
