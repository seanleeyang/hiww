import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

/// Resolved authentication state. `null` `AsyncValue` (loading) means we are
/// still checking the stored token on cold start.
sealed class AuthState {
  const AuthState();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);
  final AuthUser user;
}

class AuthController extends AsyncNotifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AuthState> build() async {
    if (!await _repo.hasToken()) return const AuthSignedOut();
    try {
      return AuthSignedIn(await _repo.me());
    } on ApiException {
      // Token missing/expired/invalid — drop it and start clean.
      await _repo.logout();
      return const AuthSignedOut();
    }
  }

  Future<void> login({
    required String email,
    required String password,
    bool staySignedIn = true,
  }) async {
    state = await AsyncValue.guard<AuthState>(
      () async => AuthSignedIn(
        await _repo.login(email: email, password: password, staySignedIn: staySignedIn),
      ),
    );
  }

  Future<void> socialLogin({
    required String provider,
    required String idToken,
    UserType? userType,
    String? redirectUri,
  }) async {
    state = await AsyncValue.guard<AuthState>(
      () async => AuthSignedIn(
        await _repo.socialLogin(
          provider: provider,
          idToken: idToken,
          userType: userType,
          redirectUri: redirectUri,
        ),
      ),
    );
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required UserType userType,
    required String phone,
  }) async {
    state = await AsyncValue.guard<AuthState>(
      () async => AuthSignedIn(
        await _repo.register(
          fullName: fullName,
          email: email,
          password: password,
          userType: userType,
          phone: phone,
        ),
      ),
    );
  }

  /// Throws [ApiException] on a wrong/expired code — callers show it inline
  /// rather than losing the signed-in state over it.
  Future<void> verifyOtp({required String channel, required String code}) async {
    final user = await _repo.verifyOtp(channel: channel, code: code);
    state = AsyncData(AuthSignedIn(user));
  }

  Future<String?> resendOtp({required String channel}) => _repo.resendOtp(channel: channel);

  Future<String?> forgotPassword({required String email}) => _repo.forgotPassword(email: email);

  /// Throws [ApiException] on a wrong/expired code — callers show it inline
  /// rather than losing the (signed-out) state over it.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final user = await _repo.resetPassword(email: email, code: code, newPassword: newPassword);
    state = AsyncData(AuthSignedIn(user));
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(AuthSignedOut());
  }

  /// Re-pull `/api/me` (e.g. after a KYC submission) without disturbing the
  /// session if it fails.
  Future<void> refreshMe() async {
    try {
      state = AsyncData(AuthSignedIn(await _repo.me()));
    } on ApiException {
      // keep the current state
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

/// Convenience: the current user, or null when not signed in.
final currentUserProvider = Provider<AuthUser?>((ref) {
  final state = ref.watch(authControllerProvider).valueOrNull;
  return state is AuthSignedIn ? state.user : null;
});
