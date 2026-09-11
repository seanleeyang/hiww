/// Google Sign-In OAuth Client ID (Web application type, Google Cloud
/// Console). Safe to keep in source — unlike a client *secret* or API key,
/// an OAuth Client ID is meant to be embedded in public clients; the backend
/// is what actually verifies the resulting token server-side (see
/// `src/modules/auth/routes.ts`'s `/api/auth/social`).
const googleClientId =
    '858012115343-pmn2jd8p4kcdpkug2h45gs6a9iqojm2a.apps.googleusercontent.com';

/// LINE Login Channel ID (LINE Developers Console → your channel → Basic
/// settings → Channel ID). Also safe to embed — like the Google Client ID
/// above, it identifies the app but proves nothing on its own; the LINE
/// Channel *Secret* stays server-side only (`LINE_CHANNEL_SECRET`).
const lineChannelId = '2011511111';

/// Facebook App ID (developers.facebook.com → your app → Settings → Basic →
/// App ID). Also safe to embed — like the two above, it identifies the app
/// but proves nothing on its own; the App *Secret* stays server-side only
/// (`FACEBOOK_APP_SECRET`).
const facebookAppId = '2131221744465635';
