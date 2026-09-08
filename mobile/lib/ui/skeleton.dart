import 'package:flutter/material.dart';

/// A softly pulsing placeholder block used while content loads.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 0.9).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Placeholder stack for the Browse feed. A plain [Column] (not a
/// `ListView`) — its only caller sits inside a `SliverToBoxAdapter`, whose
/// unbounded height a scrolling ListView can't self-size against.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(height: 130, radius: 14),
                  SizedBox(height: 12),
                  SkeletonBox(width: 160, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 220, height: 12),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder for a simple list screen.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 5});
  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: rows,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 180, height: 15),
            SizedBox(height: 8),
            SkeletonBox(width: 240, height: 12),
          ],
        ),
      ),
    );
  }
}
