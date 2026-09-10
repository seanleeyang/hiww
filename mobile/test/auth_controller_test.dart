import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/core/api/api_exception.dart';
import 'package:hiww_mobile/features/auth/application/auth_controller.dart';
import 'package:hiww_mobile/features/auth/data/auth_repository.dart';
import 'package:hiww_mobile/features/auth/domain/auth_user.dart';

const _user = AuthUser(
  id: 'u1',
  email: 'a@b.com',
  fullName: 'Ada Lovelace',
  userType: UserType.both,
  role: 'user',
  kycStatus: 'pending',
  riskStatus: 'clear',
);

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.token});

  String? token;
  AuthUser? meResult;
  Object? meError;
  bool loggedOut = false;

  @override
  Future<bool> hasToken() async => token != null;

  @override
  Future<AuthUser> me() async {
    if (meError != null) throw meError!;
    return meResult ?? _user;
  }

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
    bool staySignedIn = true,
  }) async {
    token = 'tok';
    return _user;
  }

  @override
  Future<AuthUser> socialLogin({
    required String provider,
    required String idToken,
    UserType? userType,
    String? redirectUri,
  }) async {
    token = 'tok';
    return _user;
  }

  @override
  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
    required UserType userType,
    required String phone,
  }) async {
    token = 'tok';
    return _user;
  }

  @override
  Future<AuthUser> verifyOtp({required String channel, required String code}) async => _user;

  @override
  Future<String?> resendOtp({required String channel}) async => null;

  @override
  Future<String?> forgotPassword({required String email}) async => null;

  @override
  Future<AuthUser> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    token = 'tok';
    return _user;
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
    token = null;
  }
}

ProviderContainer _containerWith(_FakeAuthRepository repo) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('no stored token resolves to signed out', () async {
    final container = _containerWith(_FakeAuthRepository());
    final state = await container.read(authControllerProvider.future);
    expect(state, isA<AuthSignedOut>());
  });

  test('valid stored token resolves to signed in', () async {
    final container = _containerWith(_FakeAuthRepository(token: 'tok'));
    final state = await container.read(authControllerProvider.future);
    expect(state, isA<AuthSignedIn>());
    expect((state as AuthSignedIn).user.id, 'u1');
  });

  test('expired token is cleared and resolves to signed out', () async {
    final repo = _FakeAuthRepository(token: 'stale')
      ..meError = ApiException('expired', statusCode: 401);
    final container = _containerWith(repo);

    final state = await container.read(authControllerProvider.future);

    expect(state, isA<AuthSignedOut>());
    expect(repo.loggedOut, isTrue);
  });

  test('login moves state to signed in', () async {
    final repo = _FakeAuthRepository();
    final container = _containerWith(repo);
    await container.read(authControllerProvider.future);

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'a@b.com', password: 'password1');

    expect(container.read(authControllerProvider).value, isA<AuthSignedIn>());
    expect(repo.token, 'tok');
  });

  test('logout moves state back to signed out', () async {
    final repo = _FakeAuthRepository(token: 'tok');
    final container = _containerWith(repo);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).logout();

    expect(container.read(authControllerProvider).value, isA<AuthSignedOut>());
    expect(repo.loggedOut, isTrue);
  });
}
