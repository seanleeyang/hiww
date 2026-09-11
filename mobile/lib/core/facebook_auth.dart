// Facebook Login here is a full-page browser redirect (no native Facebook
// SDK is wired in), so starting it and reading back its CSRF `state` only
// makes sense on the web build — behind a conditional import like
// line_auth's.
export 'facebook_auth_stub.dart' if (dart.library.html) 'facebook_auth_web.dart';
