/// Stub for the web-only LINE Login redirect starter — non-web builds show
/// a "not configured" message instead of calling this (see
/// `SocialAuthButtons`), so these should never actually run.
void startLineLogin(String channelId) => throw StateError('startLineLogin is web-only');

String? consumeLineOauthState() => throw StateError('consumeLineOauthState is web-only');

String lineRedirectUri() => throw StateError('lineRedirectUri is web-only');
