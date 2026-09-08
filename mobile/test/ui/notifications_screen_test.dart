import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/features/notifications/data/notifications_repository.dart';
import 'package:hiww_mobile/features/notifications/domain/app_notification.dart';
import 'package:hiww_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:hiww_mobile/l10n/app_localizations.dart';
import 'package:hiww_mobile/theme/app_theme.dart';

AppNotification _n({
  required String type,
  required String subject,
  DateTime? readAt,
}) =>
    AppNotification(
      id: 'n-$subject',
      type: type,
      subject: subject,
      body: 'Something about "Nike Dunk Low Panda".',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      orderId: 'order-1',
      link: '/orders/order-1',
      readAt: readAt,
    );

Widget _wrap(NotificationsFeed feed) => ProviderScope(
      overrides: [
        notificationsProvider.overrideWith((ref) => Stream.value(feed)),
      ],
      child: MaterialApp(
        theme: hiwwTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // NotificationsScreen is always embedded inside a Scaffold in
        // production (the Inbox tab's TabBarView, itself inside AppShell's
        // Scaffold) — its Expanded needs that bounded-height ancestor.
        home: const Scaffold(body: NotificationsScreen()),
      ),
    );

void main() {
  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(_wrap(NotificationsFeed.empty));
    await tester.pumpAndSettle();
    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('renders each notification with its subject and body', (tester) async {
    await tester.pumpWidget(_wrap(NotificationsFeed(
      unreadCount: 1,
      items: [
        _n(type: 'payment_confirmed', subject: 'Payment confirmed'),
        _n(type: 'shipped', subject: 'Your item is on the way', readAt: DateTime.now()),
      ],
    )));
    await tester.pumpAndSettle();

    expect(find.text('Payment confirmed'), findsOneWidget);
    expect(find.text('Your item is on the way'), findsOneWidget);
    expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
  });
}
