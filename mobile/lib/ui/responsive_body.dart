import 'package:flutter/material.dart';

/// Caps content width and centers it on wide (desktop web) viewports so
/// full-bleed banners (see [HeroImage]) don't stretch across the whole
/// window — matches the width [AppShell] already applies to the tab pages.
/// A no-op on narrow (phone) screens, where the cap never binds.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
