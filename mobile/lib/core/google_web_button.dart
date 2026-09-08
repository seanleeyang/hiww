// The Google Identity Services SDK requires web sign-in to be triggered from
// a button it renders itself, not application UI — see
// google_sign_in_web's README. `google_sign_in_web` is a web-only package,
// so it can't be imported unconditionally without breaking non-web builds.
export 'google_web_button_stub.dart' if (dart.library.js_interop) 'google_web_button_web.dart';
