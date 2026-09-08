import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// The GIS-rendered Google sign-in button — the only way to trigger web
/// sign-in interactively; custom application UI can't call `authenticate()`
/// directly on web. [width] matches it to the sibling LINE/Facebook buttons
/// (GIS caps this at 400px itself); [locale] pins its text to the app's
/// chosen language instead of the browser/Google-account's own locale,
/// which otherwise can silently disagree with the rest of the screen.
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
