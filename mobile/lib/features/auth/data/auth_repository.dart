import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/auth_user.dart';

/// Talks to the backend auth endpoints and owns token persistence.
class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
    required UserType userType,
    required String phone,
  }) async {
    final data = await _api.post('/api/auth/register', body: {
      'full_name': fullName,
      'email': email,
      'password': password,
      'user_type': userType.name,
      'phone': phone,
    });
    await _storeToken(data);
    return me();
  }

  /// Confirms a code sent to one channel at registration (or via [resendOtp]).
  Future<AuthUser> verifyOtp({required String channel, required String code}) async {
    await _api.post('/api/auth/verify-otp', body: {'channel': channel, 'code': code});
    return me();
  }

  /// Issues a fresh code for one channel; the old one stops working. Returns
  /// the code itself only while there's no real SMS/email provider wired up
  /// (`debug_otp` — see `src/services/otp/`); once one is configured this
  /// comes back null and the code only ever reaches the real inbox/phone.
  Future<String?> resendOtp({required String channel}) async {
    final data = await _api.post('/api/auth/resend-otp', body: {'channel': channel});
    return data is Map ? data['debug_otp']?.toString() : null;
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post('/api/auth/login', body: {
      'email': email,
      'password': password,
    });
    await _storeToken(data);
    return me();
  }

  /// Requests a reset code for [email]. Always resolves the same way whether
  /// or not the address is registered, so it can't be used to enumerate
  /// accounts. Returns the code itself only while there's no real email
  /// provider wired up (`debug_otp` — see `src/services/otp/`).
  Future<String?> forgotPassword({required String email}) async {
    final data = await _api.post('/api/auth/forgot-password', body: {'email': email});
    return data is Map ? data['debug_otp']?.toString() : null;
  }

  /// Confirms a reset code and sets a new password, then signs the user in
  /// with a fresh token — mirrors [register]'s "verify == sign in" shape.
  Future<AuthUser> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final data = await _api.post('/api/auth/reset-password', body: {
      'email': email,
      'code': code,
      'new_password': newPassword,
    });
    await _storeToken(data);
    return me();
  }

  Future<AuthUser> me() async {
    final data = await _api.get('/api/me');
    return AuthUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> logout() => _tokens.clear();

  Future<bool> hasToken() async {
    final token = await _tokens.read();
    return token != null && token.isNotEmpty;
  }

  Future<void> _storeToken(Object? data) async {
    final token = data is Map ? data['token']?.toString() : null;
    if (token == null || token.isEmpty) {
      throw StateError('Auth response did not include a token');
    }
    await _tokens.write(token);
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  ),
);
