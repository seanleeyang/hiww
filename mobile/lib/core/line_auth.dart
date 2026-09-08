// LINE Login here is a full-page browser redirect (no native LINE SDK is
// wired in), so starting it and reading back its CSRF `state` only makes
// sense on the web build — behind a conditional import like image_saver's.
export 'line_auth_stub.dart' if (dart.library.html) 'line_auth_web.dart';
