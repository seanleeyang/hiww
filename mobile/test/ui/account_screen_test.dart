import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/app.dart';
import 'package:hiww_mobile/features/auth/data/auth_repository.dart';
import 'package:hiww_mobile/features/auth/domain/auth_user.dart';

const _me = AuthUser(
  id: 'me',
  membershipId: 'H00000123',
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
  testWidgets('membership ID starts masked, then reveals in full with a copy button offered',
      (tester) async {
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

    await tester.tap(find.byTooltip('Account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Masked: first 6 characters shown, the rest replaced by a literal
    // "XXX" — not the full number, and no email/home-city line either
    // (that's already in the Personal information card below).
    expect(find.text('H00000XXX'), findsOneWidget);
    expect(find.text('H00000123'), findsNothing);
    // The email is still shown once, in the Personal information card below
    // — just no longer duplicated in the header under the name.
    expect(find.text('me@test.dev'), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.text('H00000123'), findsOneWidget);
    expect(find.text('H00000XXX'), findsNothing);
    // The copy button only appears once revealed — copying a masked value
    // wouldn't make sense.
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
  });
}
