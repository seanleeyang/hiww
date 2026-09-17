import 'package:flutter/material.dart';

/// The app's launch screen — a solid Tangelo field with the mark centered,
/// shown while auth resolves. See app_router.dart's `_revealTransition` for
/// the Wise-style "rising panel" effect used when leaving this screen for
/// onboarding/landing: it clips the *incoming* page to a growing shape, so
/// this screen (staying mounted underneath, unanimated, during that
/// transition) is what shows through outside the growing area.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFB4D00),
      body: Center(
        child: Image(
          image: AssetImage('assets/images/hiww_mark_white.png'),
          width: 56,
        ),
      ),
    );
  }
}
