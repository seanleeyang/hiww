import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/theme/app_theme.dart';
import 'package:hiww_mobile/ui/initials_avatar.dart';
import 'package:hiww_mobile/ui/star_rating.dart';
import 'package:hiww_mobile/ui/status_pill.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: hiwwTheme(Brightness.light),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('StatusPill renders a humanised, capitalized label', (tester) async {
    await tester.pumpWidget(_wrap(const StatusPill('pending_payment')));
    expect(find.text('Awaiting payment'), findsOneWidget);
  });

  testWidgets('StatusPill maps in_transit to "Shipped"', (tester) async {
    await tester.pumpWidget(_wrap(const StatusPill('in_transit')));
    expect(find.text('Shipped'), findsOneWidget);
  });

  testWidgets('StatusPill maps purchased to "Items purchased"', (tester) async {
    await tester.pumpWidget(_wrap(const StatusPill('purchased')));
    expect(find.text('Items purchased'), findsOneWidget);
  });

  testWidgets('InitialsAvatar shows initials when no url', (tester) async {
    await tester.pumpWidget(_wrap(const InitialsAvatar(name: 'Ada Lovelace')));
    expect(find.text('AL'), findsOneWidget);
  });

  testWidgets('StarRatingDisplay shows "New" at zero rating', (tester) async {
    await tester.pumpWidget(_wrap(const StarRatingDisplay(rating: 0)));
    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('StarRatingInput reports the tapped star', (tester) async {
    int? picked;
    await tester.pumpWidget(_wrap(
      StarRatingInput(value: 0, onChanged: (v) => picked = v),
    ));
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
    expect(picked, 4);
  });
}
