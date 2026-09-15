import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/theme/app_theme.dart';
import 'package:hiww_mobile/ui/onboarding_progress_bar.dart';

Widget _wrap(int step, int totalSteps) => MaterialApp(
      theme: hiwwTheme(Brightness.light),
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: OnboardingProgressBar(step: step, totalSteps: totalSteps),
        ),
      ),
    );

double _fillWidth(WidgetTester tester) => tester
    .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
    .first
    .constraints!
    .maxWidth;

void main() {
  // The widget's own horizontal padding (20px each side) eats 40px of the
  // 300px SizedBox before the bar itself is measured, so the track is
  // actually 260px wide — these expectations are fractions of that, not of
  // the outer 300px box.
  const trackWidth = 260.0;

  testWidgets('fills a quarter of the track on the first of four steps', (tester) async {
    await tester.pumpWidget(_wrap(0, 4));
    expect(_fillWidth(tester), closeTo(trackWidth * 0.25, 0.5));
  });

  testWidgets('fills half the track on the second of four steps', (tester) async {
    await tester.pumpWidget(_wrap(1, 4));
    expect(_fillWidth(tester), closeTo(trackWidth * 0.5, 0.5));
  });

  testWidgets('fills the entire track on the last step', (tester) async {
    await tester.pumpWidget(_wrap(3, 4));
    expect(_fillWidth(tester), closeTo(trackWidth, 0.5));
  });
}
