import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/features/auth/application/auth_controller.dart';
import 'package:hiww_mobile/features/auth/domain/auth_user.dart';
import 'package:hiww_mobile/features/orders/data/orders_repository.dart';
import 'package:hiww_mobile/features/orders/domain/order.dart';
import 'package:hiww_mobile/features/orders/presentation/my_orders_screen.dart';
import 'package:hiww_mobile/features/shared/domain/user_summary.dart';
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

Widget _wrap(List<Order> orders) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_me),
        myOrdersProvider.overrideWith((ref) async => orders),
      ],
      child: MaterialApp(
        theme: hiwwTheme(Brightness.light),
        home: const MyOrdersScreen(),
      ),
    );

void main() {
  testWidgets('empty state when there are no orders', (tester) async {
    await tester.pumpWidget(_wrap([]));
    await tester.pumpAndSettle();

    expect(find.text('No orders yet'), findsOneWidget);
  });

  testWidgets('shows the shopper-side next step for an unpaid order', (tester) async {
    await tester.pumpWidget(_wrap([_order(status: 'pending_payment')]));
    await tester.pumpAndSettle();

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

  testWidgets('finished orders sink below active ones', (tester) async {
    await tester.pumpWidget(_wrap([
      _order(status: 'delivered', item: 'Done Item'),
      _order(status: 'in_transit', item: 'Active Item'),
    ]));
    await tester.pumpAndSettle();

    final active = tester.getTopLeft(find.text('Active Item')).dy;
    final done = tester.getTopLeft(find.text('Done Item')).dy;
    expect(active, lessThan(done));
  });
}
