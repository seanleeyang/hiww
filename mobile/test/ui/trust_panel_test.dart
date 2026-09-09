import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/features/orders/domain/order.dart';
import 'package:hiww_mobile/features/orders/presentation/trust_panel.dart';
import 'package:hiww_mobile/l10n/app_localizations.dart';
import 'package:hiww_mobile/theme/app_theme.dart';

Order _order({required String status}) => Order(
      id: 'o1',
      shopperId: 's',
      travelerId: 't',
      itemDescription: 'Dyson Airwrap',
      totalPrice: '18000',
      fees: '1200',
      status: status,
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: hiwwTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('shopper sees the original "you confirm" wording while funds are held', (tester) async {
    await tester.pumpWidget(_wrap(TrustPanel(order: _order(status: 'in_transit'), isShopper: true)));
    expect(find.text('Hiww is holding ฿18,000 + ฿1,200 fee'), findsOneWidget);
    expect(find.text('Released to the traveler when you confirm you have the item.'), findsOneWidget);
  });

  testWidgets('traveler sees the same holding line but traveler-appropriate release wording', (tester) async {
    await tester.pumpWidget(_wrap(TrustPanel(order: _order(status: 'in_transit'), isShopper: false)));
    expect(find.text('Hiww is holding ฿18,000 + ฿1,200 fee'), findsOneWidget);
    expect(find.text('Released to you once the shopper receives the item and confirms it.'), findsOneWidget);
  });
}
