import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// The GIS-rendered Google sign-in button — the only way to trigger web
/// sign-in interactively; custom application UI can't call `authenticate()`
/// directly on web. [width] matches it to the sibling LINE/Facebook buttons
/// (GIS caps this at 400px itself); [locale] pins its text to the app's
/// chosen language instead of the browser/Google-account's own locale,
/// which otherwise can silently disagree with the rest of the screen.
/// `pill` (GIS's other option, `rectangular`, still renders with a fairly
/// generous corner radius that looked barely different from `pill` at this
/// button height) — `SocialAuthButtons` gives the LINE/Facebook buttons a
/// matching `StadiumBorder` instead of trying to make Google's cross-origin
/// iframe match this app's own 16px-radius theme, which GIS has no way to
/// express exactly.
Widget renderGoogleButton({required double width, required String locale}) => web.renderButton(
  configuration: web.GSIButtonConfiguration(
    theme: web.GSIButtonTheme.outline,
    size: web.GSIButtonSize.large,
    shape: web.GSIButtonShape.pill,
    text: web.GSIButtonText.signinWith,
    logoAlignment: web.GSIButtonLogoAlignment.left,
    minimumWidth: width,
    locale: locale,
  ),
);
