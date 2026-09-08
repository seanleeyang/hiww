// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// dart:html is fine here — this file is only ever selected for the web
// target via the conditional export in line_auth.dart, never bundled into
// the mobile/desktop build.
import 'dart:html' as html;
import 'dart:math';

const _lineStateStorageKey = 'hiww_line_oauth_state';

/// The exact redirect_uri LINE will send the browser back to after login —
/// also sent to the backend so its token exchange (a second, separate call
/// to LINE) uses the identical value the authorize request did.
String lineRedirectUri() => '${html.window.location.origin}/line-callback';

String _randomState() {
  final rand = Random.secure();
  return List.generate(24, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Starts LINE Login: stashes a CSRF `state` value in session storage (so
/// `/line-callback` can confirm the redirect it receives is the one this tab
/// started, not a replayed or forged URL), then does a full-page redirect to
/// LINE's authorize endpoint — LINE Login requires this to be a real
/// top-level navigation, not a popup or XHR.
void startLineLogin(String channelId) {
  final state = _randomState();
  html.window.sessionStorage[_lineStateStorageKey] = state;
  final authorizeUrl = Uri.https('access.line.me', '/oauth2/v2.1/authorize', {
    'response_type': 'code',
    'client_id': channelId,
    'redirect_uri': lineRedirectUri(),
    'state': state,
    'scope': 'profile openid email',
  });
  html.window.location.href = authorizeUrl.toString();
}

/// Reads back the `state` [startLineLogin] stashed and clears it — a
/// one-time read so a replayed callback URL can't be reused.
String? consumeLineOauthState() {
  final value = html.window.sessionStorage[_lineStateStorageKey];
  html.window.sessionStorage.remove(_lineStateStorageKey);
  return value;
}
