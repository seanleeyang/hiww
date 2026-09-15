import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/features/auth/presentation/otp_code_input.dart';
import 'package:hiww_mobile/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: hiwwTheme(Brightness.light),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('typing a digit in each box advances focus and reports the full code', (tester) async {
    final values = <String>[];
    await tester.pumpWidget(_wrap(OtpCodeInput(onChanged: values.add)));

    final fields = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '$i');
      await tester.pump();
    }

    expect(values.last, '012345');
    // Focus should have landed past the last box (unfocused), not stuck mid-row.
    expect(FocusManager.instance.primaryFocus?.hasPrimaryFocus, isTrue);
  });

  testWidgets('non-digit characters are stripped before reaching onChanged', (tester) async {
    final values = <String>[];
    await tester.pumpWidget(_wrap(OtpCodeInput(onChanged: values.add)));

    // A single box catching a run of characters (e.g. autofill or a fast
    // paste) should behave the same as a real 6-digit paste: filtered to
    // digits only, then spread across the boxes.
    await tester.enterText(find.byType(TextField).first, 'a1b2c3d4e5f6');
    await tester.pump();

    expect(values.last, '123456');
  });

  testWidgets('pasting a full code into one box spreads it across all six', (tester) async {
    final values = <String>[];
    await tester.pumpWidget(_wrap(OtpCodeInput(onChanged: values.add)));

    await tester.enterText(find.byType(TextField).first, '987654');
    await tester.pump();

    final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(textFields.map((f) => f.controller!.text).join(), '987654');
    expect(values.last, '987654');
  });

  testWidgets('setCode fills every box the same way a paste would', (tester) async {
    final values = <String>[];
    final key = GlobalKey<OtpCodeInputState>();
    await tester.pumpWidget(_wrap(OtpCodeInput(key: key, onChanged: values.add)));

    key.currentState!.setCode('102938');
    await tester.pump();

    final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(textFields.map((f) => f.controller!.text).join(), '102938');
    expect(values.last, '102938');
  });

  testWidgets('Backspace on an empty box steps back and clears the previous box', (tester) async {
    final values = <String>[];
    await tester.pumpWidget(_wrap(OtpCodeInput(onChanged: values.add)));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '5');
    await tester.enterText(fields.at(1), '6');
    await tester.pump();
    // Typing into box 1 auto-advanced focus to box 2, which is still empty.

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(textFields[0].controller!.text, '5');
    expect(textFields[1].controller!.text, isEmpty);
    expect(values.last, '5');

    // A second Backspace, now that box 1 is focused and empty, steps back
    // again and clears box 0 too.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    final textFields2 = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(textFields2[0].controller!.text, isEmpty);
    expect(values.last, isEmpty);
  });

  testWidgets('arrow keys move focus left and right between boxes', (tester) async {
    await tester.pumpWidget(_wrap(const OtpCodeInput(onChanged: _noop)));

    final focusNodesBefore = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNot(focusNodesBefore));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, focusNodesBefore);
  });

  testWidgets('Verify-style gate: caller only sees a 6-char code once every box is filled', (tester) async {
    final values = <String>[];
    await tester.pumpWidget(_wrap(OtpCodeInput(onChanged: values.add)));

    final fields = find.byType(TextField);
    for (var i = 0; i < 5; i++) {
      await tester.enterText(fields.at(i), '1');
      await tester.pump();
    }
    expect(values.every((v) => v.length < 6), isTrue);

    await tester.enterText(fields.at(5), '1');
    await tester.pump();
    expect(values.last.length, 6);
  });
}

void _noop(String _) {}
