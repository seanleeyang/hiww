import 'package:flutter/material.dart';

import 'central_video.dart';

/// A central gradient blob holding [icon], with small satellite badges
/// gently bobbing above it — Hiww's flat-shape stand-in for the reference
/// design's bespoke floating 3D objects until real illustration assets are
/// ready (see the paused "Wise-style onboarding redesign" memory note).
/// Pass [videoAsset] once a real animation exists for a given slide — it
/// replaces the flat icon as the central object; [icon] stays required as
/// the fallback for slides that don't have one yet.
class FloatingOrbitIllustration extends StatefulWidget {
  const FloatingOrbitIllustration({
    super.key,
    required this.icon,
    this.satelliteIcons = const [],
    this.videoAsset,
  });

  final IconData icon;
  final List<IconData> satelliteIcons;
  final String? videoAsset;

  @override
  State<FloatingOrbitIllustration> createState() => _FloatingOrbitIllustrationState();
}

class _FloatingOrbitIllustrationState extends State<FloatingOrbitIllustration>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    // Each satellite bobs on its own slightly-different duration so they
    // drift out of sync with one another, rather than bobbing in lockstep.
    _controllers = List.generate(
      widget.satelliteIcons.length,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 2200 + i * 420),
      )..repeat(reverse: true),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  static const _positions = [
    Alignment(-0.6, -0.92),
    Alignment(0.62, -0.7),
    Alignment(-0.1, -1.1),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < widget.satelliteIcons.length; i++)
            Align(
              alignment: _positions[i % _positions.length],
              child: AnimatedBuilder(
                animation: _controllers[i],
                builder: (context, child) {
                  final dy = -8 * Curves.easeInOut.transform(_controllers[i].value);
                  return Transform.translate(offset: Offset(0, dy), child: child);
                },
                child: _Satellite(icon: widget.satelliteIcons[i]),
              ),
            ),
          if (widget.videoAsset != null)
            CentralVideo(asset: widget.videoAsset!, size: 220)
          else
            _CentralBlob(icon: widget.icon),
        ],
      ),
    );
  }
}

/// The central object itself — no colored disc behind it. The reference
/// (Wise) floats its 3D objects directly against the background with
/// nothing framing them; an earlier pass here used a solid gradient circle
/// that read more like a Headspace-style icon badge than an object floating
/// in space, which is why it's gone.
class _CentralBlob extends StatelessWidget {
  const _CentralBlob({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(icon, size: 128, color: scheme.primary);
  }
}

class _Satellite extends StatelessWidget {
  const _Satellite({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: scheme.primary),
    );
  }
}
