import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/features/orders/domain/order.dart';
import 'package:hiww_mobile/features/orders/presentation/order_stepper.dart';
import 'package:hiww_mobile/l10n/app_localizations.dart';
import 'package:hiww_mobile/theme/app_theme.dart';

Order _order(String status,
        {DateTime? confirmed, DateTime? purchased, DateTime? shipped, DateTime? delivered}) =>
    Order(
      id: 'o1',
      shopperId: 's',
      travelerId: 't',
      itemDescription: 'Dyson Airwrap',
      totalPrice: '18000',
      fees: '1200',
      status: status,
      createdAt: DateTime(2026, 11, 2),
      confirmedAt: confirmed,
      purchasedAt: purchased,
      shippedAt: shipped,
      deliveredAt: delivered,
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: hiwwTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders all five stages', (tester) async {
    await tester.pumpWidget(_wrap(OrderStepper(order: _order('pending_payment'))));
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Bought'), findsOneWidget);
    expect(find.text('In transit'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
  });

  testWidgets('shows the date for a completed stage', (tester) async {
    await tester.pumpWidget(_wrap(OrderStepper(
      order: _order('in_transit',
          confirmed: DateTime(2026, 11, 14), shipped: DateTime(2026, 11, 15)),
    )));
    expect(find.text('Nov 14'), findsOneWidget); // Paid
    expect(find.text('Nov 15'), findsOneWidget); // In transit
    expect(find.text('Confirm to release payment'), findsOneWidget); // Delivered hint
  });

  testWidgets('a delivered order shows every stage complete', (tester) async {
    await tester.pumpWidget(_wrap(OrderStepper(
      order: _order('delivered',
          confirmed: DateTime(2026, 11, 14),
          purchased: DateTime(2026, 11, 15),
          shipped: DateTime(2026, 11, 16),
          delivered: DateTime(2026, 11, 20)),
    )));
    // Once delivered, all five dots read as done — including "Delivered".
    expect(find.byIcon(Icons.check), findsNWidgets(5));
  });

  testWidgets('mid-flight, the Bought stage is current, not yet checked', (tester) async {
    await tester.pumpWidget(_wrap(OrderStepper(
      order: _order('purchased',
          confirmed: DateTime(2026, 11, 14), purchased: DateTime(2026, 11, 15)),
    )));
    // Accepted + Paid done; Bought is the current step.
    expect(find.byIcon(Icons.check), findsNWidgets(2));
  });

  testWidgets('once payment is confirmed, Paid ticks immediately rather than waiting for Bought', (tester) async {
    await tester.pumpWidget(_wrap(OrderStepper(
      order: _order('confirmed', confirmed: DateTime(2026, 11, 14)),
    )));
    // Accepted + Paid done as soon as payment is confirmed — Bought is now
    // the current (in-progress) step, not yet checked.
    expect(find.byIcon(Icons.check), findsNWidgets(2));
  });
}
