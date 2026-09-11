import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/app.dart';
import 'package:hiww_mobile/features/auth/data/auth_repository.dart';
import 'package:hiww_mobile/features/auth/domain/auth_user.dart';

TextSpan? _findSpan(InlineSpan span, bool Function(TextSpan) test) {
  if (span is! TextSpan) return null;
  if (test(span)) return span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final found = _findSpan(child, test);
    if (found != null) return found;
  }
  return null;
}

class _SignedOutRepository implements AuthRepository {
  @override
  Future<bool> hasToken() async => false;

  @override
  Future<AuthUser> me() => throw UnimplementedError();

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
    bool staySignedIn = true,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> socialLogin({
    required String provider,
    required String idToken,
    UserType? userType,
    String? redirectUri,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
    required UserType userType,
    required String phone,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> verifyOtp({required String channel, required String code}) =>
      throw UnimplementedError();

  @override
  Future<String?> resendOtp({required String channel}) => throw UnimplementedError();

  @override
  Future<String?> forgotPassword({required String email}) => throw UnimplementedError();

  @override
  Future<AuthUser> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets(
      'unauthenticated launch shows the landing screen, and Log in opens the login screen',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedOutRepository()),
        ],
        child: const HiwwApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Landing screen first — social buttons, email path, guest link.
    expect(find.text('Explore Hiww — create an account later'), findsOneWidget);

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);

    final toggleFinder = find.byWidgetPredicate(
      (w) => w is RichText && (w.text as TextSpan).toPlainText().contains('ไทย'),
    );
    expect(toggleFinder, findsOneWidget);
    final toggleSpan = tester.widget<RichText>(toggleFinder).text as TextSpan;
    expect(toggleSpan.toPlainText(), 'English | ไทย');

    final thaiSpan = _findSpan(toggleSpan, (s) => s.text == 'ไทย');
    expect(thaiSpan, isNotNull);
    (thaiSpan!.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();

    expect(find.text('ยินดีต้อนรับกลับ'), findsOneWidget);
  });

  testWidgets('forgot password link opens the reset flow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedOutRepository()),
        ],
        child: const HiwwApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    // The social buttons above the email form push "Forgot password?" below
    // the fold in the test viewport — scroll it into view first.
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Send code'), findsOneWidget);
  });
}
