// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// dart:html is fine here — this file is only ever selected for the web
// target via the conditional export in facebook_auth.dart, never bundled
// into the mobile/desktop build.
import 'dart:html' as html;
import 'dart:math';

const _facebookStateStorageKey = 'hiww_facebook_oauth_state';

/// The exact redirect_uri Facebook will send the browser back to after
/// login — also sent to the backend so its token exchange (a second,
/// separate call to Facebook) uses the identical value the authorize
/// request did.
String facebookRedirectUri() => '${html.window.location.origin}/facebook-callback';

String _randomState() {
  final rand = Random.secure();
  return List.generate(24, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Starts Facebook Login: stashes a CSRF `state` value in session storage
/// (so `/facebook-callback` can confirm the redirect it receives is the one
/// this tab started, not a replayed or forged URL), then does a full-page
/// redirect to Facebook's authorize endpoint — same shape as LINE Login,
/// since Facebook has no client-side ID token either.
void startFacebookLogin(String appId) {
  final state = _randomState();
  html.window.sessionStorage[_facebookStateStorageKey] = state;
  final authorizeUrl = Uri.https('www.facebook.com', '/v21.0/dialog/oauth', {
    'response_type': 'code',
    'client_id': appId,
    'redirect_uri': facebookRedirectUri(),
    'state': state,
    'scope': 'public_profile,email',
  });
  html.window.location.href = authorizeUrl.toString();
}

/// Reads back the `state` [startFacebookLogin] stashed and clears it — a
/// one-time read so a replayed callback URL can't be reused.
String? consumeFacebookOauthState() {
  final value = html.window.sessionStorage[_facebookStateStorageKey];
  html.window.sessionStorage.remove(_facebookStateStorageKey);
  return value;
}
