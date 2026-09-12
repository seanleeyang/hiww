import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/features/discovery/presentation/feed_cards.dart';
import 'package:hiww_mobile/features/shared/domain/user_summary.dart';
import 'package:hiww_mobile/features/trips/domain/trip.dart';
import 'package:hiww_mobile/features/wants/domain/want.dart';
import 'package:hiww_mobile/l10n/app_localizations.dart';
import 'package:hiww_mobile/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: hiwwTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('TripFeedCard shows route, traveler and earn badge', (tester) async {
    await tester.pumpWidget(_wrap(TripFeedCard(
      trip: Trip(
        id: 't1',
        travelerId: 'u1',
        departureCountry: 'TH',
        arrivalCountry: 'JP',
        arrivalCity: 'Tokyo',
        departureDate: DateTime(2026, 11, 12),
        returnDate: DateTime(2026, 11, 19),
        maxWeightKg: 8,
      ),
      traveler: const UserSummary(id: 'u1', fullName: 'Nuch S', ratingAvg: 4.9, deliveredCount: 147),
      earnMin: '1200',
      earnMax: '1200',
      matchCount: 2,
    )));

    expect(find.text('Nuch S'), findsOneWidget);
    expect(find.textContaining('Bangkok → Tokyo'), findsOneWidget);
    expect(find.text('Earn ฿1,200'), findsOneWidget);
    expect(find.textContaining('147 delivered'), findsOneWidget);
  });

  testWidgets('WantFeedCard shows title, budget and route hint', (tester) async {
    await tester.pumpWidget(_wrap(WantFeedCard(
      want: Want(
        id: 'w1',
        shopperId: 'u2',
        itemDescription: 'Nike Dunk Low Panda',
        sourceCountry: 'JP',
        sourceCity: 'Tokyo',
        category: 'sneakers',
        budget: '6500.00',
        title: 'Nike Dunk Panda',
      ),
      shopper: const UserSummary(id: 'u2', fullName: 'Mika K'),
      matchCount: 3,
    )));

    expect(find.text('Nike Dunk Panda'), findsOneWidget);
    expect(find.textContaining('฿6,500'), findsOneWidget);
    expect(find.textContaining('3 travelers on this route'), findsOneWidget);
    expect(find.textContaining('wants from Tokyo'), findsOneWidget);
  });
}
