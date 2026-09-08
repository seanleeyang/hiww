import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/features/auth/application/auth_controller.dart';
import 'package:hiww_mobile/features/auth/domain/auth_user.dart';
import 'package:hiww_mobile/features/orders/data/orders_repository.dart';
import 'package:hiww_mobile/features/orders/domain/order.dart';
import 'package:hiww_mobile/features/orders/presentation/my_orders_screen.dart';
import 'package:hiww_mobile/features/shared/domain/user_summary.dart';
import 'package:hiww_mobile/features/wants/data/offers_repository.dart';
import 'package:hiww_mobile/features/wants/data/wants_repository.dart';
import 'package:hiww_mobile/features/wants/domain/offer.dart';
import 'package:hiww_mobile/features/wants/domain/want.dart';
import 'package:hiww_mobile/l10n/app_localizations.dart';
import 'package:hiww_mobile/theme/app_theme.dart';

const _me = AuthUser(
  id: 'me',
  email: 'me@test.dev',
  fullName: 'Me Tester',
  userType: UserType.both,
  role: 'user',
  kycStatus: 'approved',
  riskStatus: 'clear',
);

Order _order({
  required String status,
  bool iAmShopper = true,
  String item = 'Nike Dunk Low Panda',
}) =>
    Order(
      id: 'order-${status}1',
      shopperId: iAmShopper ? 'me' : 'other',
      travelerId: iAmShopper ? 'other' : 'me',
      itemDescription: item,
      totalPrice: '6500.00',
      fees: '325.00',
      status: status,
      counterparty: const UserSummary(id: 'other', fullName: 'Nuch S'),
      createdAt: DateTime(2026, 9, 1),
    );

Widget _wrap(
  List<Order> orders, {
  List<Want> wants = const [],
  List<Offer> negotiations = const [],
}) =>
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_me),
        myOrdersProvider.overrideWith((ref) async => orders),
        myWantsProvider.overrideWith((ref) async => wants),
        negotiationsProvider.overrideWith((ref) async => negotiations),
      ],
      child: MaterialApp(
        theme: hiwwTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MyOrdersScreen(),
      ),
    );

/// Tabs are labelled with a live count (e.g. "1 in transit"), so tests tap
/// by ordinal position rather than exact text.
Future<void> _tapTab(WidgetTester tester, int index) async {
  await tester.tap(find.byType(Tab).at(index));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state when there is nothing requested', (tester) async {
    await tester.pumpWidget(_wrap([]));
    await tester.pumpAndSettle();

    expect(find.text('No wants yet'), findsOneWidget);
  });

  testWidgets('shows the shopper-side next step for an unpaid order', (tester) async {
    await tester.pumpWidget(_wrap([_order(status: 'pending_payment')]));
    await tester.pumpAndSettle();

    // pending_payment sits in the default (Requested) tab, no tab switch needed.
    expect(find.text('Nike Dunk Low Panda'), findsOneWidget);
    expect(find.text('Buying from Nuch S'), findsOneWidget);
    expect(find.text('Pay to get things moving'), findsOneWidget);
  });

  testWidgets('shows the traveler-side next step for the same stage', (tester) async {
    await tester.pumpWidget(_wrap([_order(status: 'confirmed', iAmShopper: false)]));
    await tester.pumpAndSettle();

    expect(find.text('Delivering for Nuch S'), findsOneWidget);
    expect(find.text('Buy the item, then upload the receipt'), findsOneWidget);
  });

  testWidgets('purchased stage tells the traveler to ship', (tester) async {
    await tester.pumpWidget(_wrap([_order(status: 'purchased', iAmShopper: false)]));
    await tester.pumpAndSettle();
    expect(find.text('Post the item, then mark it shipped'), findsOneWidget);
  });

  testWidgets('in_transit and delivered orders sort into separate tabs', (tester) async {
    await tester.pumpWidget(_wrap([
      _order(status: 'delivered', item: 'Done Item'),
      _order(status: 'in_transit', item: 'Active Item'),
    ]));
    await tester.pumpAndSettle();

    // Requested (default): neither has shipped/arrived yet at this stage, so
    // neither in_transit nor delivered orders belong here.
    expect(find.text('Done Item'), findsNothing);
    expect(find.text('Active Item'), findsNothing);

    await _tapTab(tester, 1); // In Transit
    expect(find.text('Active Item'), findsOneWidget);
    expect(find.text('Done Item'), findsNothing);

    await _tapTab(tester, 2); // Received
    expect(find.text('Done Item'), findsOneWidget);
    expect(find.text('Active Item'), findsNothing);
  });

  testWidgets('a cancelled order shows under Inactive', (tester) async {
    await tester.pumpWidget(_wrap([_order(status: 'cancelled', item: 'Cancelled Item')]));
    await tester.pumpAndSettle();

    expect(find.text('Cancelled Item'), findsNothing);
    await _tapTab(tester, 3); // Inactive
    expect(find.text('Cancelled Item'), findsOneWidget);
  });

  testWidgets('an unaccepted want shows under Requested', (tester) async {
    await tester.pumpWidget(_wrap(
      [],
      wants: [
        Want(
          id: 'want-1',
          shopperId: 'me',
          itemDescription: 'Nike Dunk Low Panda',
          sourceCountry: 'JP',
          category: 'sneakers',
          budget: '5000.00',
          status: 'open',
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nike Dunk Low Panda'), findsOneWidget);
  });
}
