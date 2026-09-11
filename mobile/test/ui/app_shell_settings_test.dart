import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/app.dart';
import 'package:hiww_mobile/features/auth/data/auth_repository.dart';
import 'package:hiww_mobile/features/auth/domain/auth_user.dart';

const _me = AuthUser(
  id: 'me',
  email: 'me@test.dev',
  fullName: 'Me Tester',
  userType: UserType.both,
  role: 'user',
  kycStatus: 'approved',
  riskStatus: 'clear',
  emailVerified: true,
  phoneVerified: true,
);

class _SignedInRepository implements AuthRepository {
  @override
  Future<bool> hasToken() async => true;

  @override
  Future<AuthUser> me() async => _me;

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
  testWidgets('app bar shows the language toggle directly and the account avatar',
      (tester) async {
    // The browse screen's feed/notification streams hit a real (unreachable)
    // network in this test, so their AsyncValueView stays in a spinning
    // loading state — an indeterminate CircularProgressIndicator schedules
    // frames forever, so pumpAndSettle would never return. Bounded pumps
    // instead: enough for the router redirect + auth resolution, not for
    // every child provider to settle.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedInRepository()),
        ],
        child: const HiwwApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Signed-in launch lands on Browse, inside the shell app bar. The bell
    // is gone — notifications now live inside the Inbox tab instead. The
    // language toggle (rendered as one "English | ไทย" rich-text widget, see
    // LanguageToggle) is right there in the app bar (top right) instead of
    // buried behind a settings gear + a whole extra screen, which no longer
    // exists at all.
    expect(find.byIcon(Icons.notifications_none), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    expect(find.textContaining('English'), findsOneWidget);
    expect(find.textContaining('ไทย'), findsOneWidget);
    expect(find.byTooltip('Account'), findsOneWidget);
  });
}
