import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/l10n/app_localizations.dart';
import 'package:hiww_mobile/theme/app_theme.dart';
import 'package:hiww_mobile/ui/image_picker_field.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: hiwwTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('empty banner shows the label and a prompt icon', (tester) async {
    await tester.pumpWidget(_wrap(
      ImagePickerField(value: null, onChanged: (_) {}, label: 'Add a photo'),
    ));

    expect(find.text('Add a photo'), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
    expect(find.text('Change'), findsNothing);
  });

  testWidgets('with a value it offers "Change" and drops the prompt',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ImagePickerField(
        value: 'https://example.com/a.jpg',
        onChanged: (_) {},
        label: 'Add a photo',
      ),
    ));
    await tester.pump();

    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Add a photo'), findsNothing);
  });

  testWidgets('circle variant renders a prompt icon when empty', (tester) async {
    await tester.pumpWidget(_wrap(
      ImagePickerField(
        value: null,
        onChanged: (_) {},
        label: 'Profile photo',
        circle: true,
      ),
    ));

    expect(find.byType(CircleAvatar), findsWidgets);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
  });
}
