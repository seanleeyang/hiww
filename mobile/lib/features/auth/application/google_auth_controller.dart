import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/social_auth_config.dart';
import 'auth_controller.dart';

/// The most recent Google sign-in failure, for [SocialAuthButtons] to show
/// as a snackbar — surfaced this way (rather than a thrown exception)
/// because sign-in completes via [GoogleSignIn.authenticationEvents], not a
/// button's own onPressed future, on web.
final googleAuthErrorProvider = StateProvider<String?>((ref) => null);

/// Owns the [GoogleSignIn] singleton's lifecycle: initializes it exactly
/// once (required by the plugin, calling it twice is undefined behavior —
/// this class is itself a non-autoDispose provider so it survives
/// navigating between the landing/login/register screens that all render a
/// Google button), and forwards sign-in events into [AuthController].
class GoogleAuthController {
  GoogleAuthController(this._ref) {
    _initFuture = _init();
  }

  final Ref _ref;
  late final Future<void> _initFuture;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;

  Future<void> _init() async {
    try {
      // No serverClientId: it requests an offline server auth code, which
      // google_sign_in_web asserts against on Web ("not supported on Web")
      // — we only need the client-side ID token verified in
      // verifyGoogleToken(), not a backend auth code.
      await GoogleSignIn.instance.initialize(clientId: googleClientId);
      _sub = GoogleSignIn.instance.authenticationEvents.listen(
        _handleEvent,
        onError: (Object e) => _setError(e),
      );
    } catch (_) {
      // No real Google Sign-In platform channel available (widget tests,
      // or a genuinely unsupported environment) — the button just won't do
      // anything if tapped, rather than crashing the whole auth screen.
    }
  }

  Future<void> _handleEvent(GoogleSignInAuthenticationEvent event) async {
    final GoogleSignInAccount? user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
    final idToken = user?.authentication.idToken;
    if (idToken == null) return;
    await _ref
        .read(authControllerProvider.notifier)
        .socialLogin(provider: 'google', idToken: idToken);
  }

  void _setError(Object e) {
    if (e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled) {
      return; // The user closed the picker — not an error worth surfacing.
    }
    _ref.read(googleAuthErrorProvider.notifier).state = e.toString();
  }

  /// Triggers the interactive sign-in flow on platforms where custom UI is
  /// allowed to start it (i.e. not web — see `SocialAuthButtons`, which
  /// renders Google's own button on web instead of calling this).
  Future<void> signInWithCustomButton() async {
    await _initFuture;
    if (!GoogleSignIn.instance.supportsAuthenticate()) return;
    try {
      await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      _setError(e);
    }
  }

  void dispose() => _sub?.cancel();
}

final googleAuthControllerProvider = Provider<GoogleAuthController>((ref) {
  final controller = GoogleAuthController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
