import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/theme/app_theme.dart';
import 'package:hiww_mobile/ui/floating_orbit_illustration.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: hiwwTheme(Brightness.light),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('renders the central icon and every satellite icon', (tester) async {
    await tester.pumpWidget(_wrap(const FloatingOrbitIllustration(
      icon: Icons.travel_explore_outlined,
      satelliteIcons: [Icons.shopping_bag_outlined, Icons.public],
    )));

    expect(find.byIcon(Icons.travel_explore_outlined), findsOneWidget);
    expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
    expect(find.byIcon(Icons.public), findsOneWidget);
  });

  testWidgets('satellites actually bob over time rather than sitting static', (tester) async {
    await tester.pumpWidget(_wrap(const FloatingOrbitIllustration(
      icon: Icons.travel_explore_outlined,
      satelliteIcons: [Icons.shopping_bag_outlined, Icons.public],
    )));

    double dyOf(IconData icon) {
      final transform = tester.widget<Transform>(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(Transform)).first,
      );
      return transform.transform.getTranslation().y;
    }

    final before = dyOf(Icons.shopping_bag_outlined);
    await tester.pump(const Duration(milliseconds: 600));
    final after = dyOf(Icons.shopping_bag_outlined);

    expect(after, isNot(before));
  });

  testWidgets('works with no satellites at all', (tester) async {
    await tester.pumpWidget(_wrap(
      const FloatingOrbitIllustration(icon: Icons.savings_outlined),
    ));
    expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
  });
}
