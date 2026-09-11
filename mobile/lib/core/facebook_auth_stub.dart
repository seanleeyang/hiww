/// Stub for the web-only Facebook Login redirect starter — non-web builds
/// show a "not configured" message instead of calling this (see
/// `SocialAuthButtons`), so these should never actually run.
void startFacebookLogin(String appId) => throw StateError('startFacebookLogin is web-only');

String? consumeFacebookOauthState() => throw StateError('consumeFacebookOauthState is web-only');

String facebookRedirectUri() => throw StateError('facebookRedirectUri is web-only');
