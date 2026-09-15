import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/l10n/app_localizations.dart';
import 'package:hiww_mobile/theme/app_theme.dart';
import 'package:hiww_mobile/ui/password_requirements_checklist.dart';

Widget _wrap(String password) => MaterialApp(
      theme: hiwwTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PasswordRequirementsChecklist(password: password)),
    );

void main() {
  testWidgets('every row is a muted dot for an empty password', (tester) async {
    await tester.pumpWidget(_wrap(''));
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('rows flip to a green check one at a time as their rule is met', (tester) async {
    // Length only.
    await tester.pumpWidget(_wrap('abcdefgh'));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // Length + a number.
    await tester.pumpWidget(_wrap('abcdefg1'));
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

    // Length + a number + a symbol.
    await tester.pumpWidget(_wrap('abcdefg1!'));
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));

    // All four: length, number, symbol, mixed case.
    await tester.pumpWidget(_wrap('Abcdefg1!'));
    expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
  });
}
