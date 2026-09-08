import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// The GIS-rendered Google sign-in button — the only way to trigger web
/// sign-in interactively; custom application UI can't call `authenticate()`
/// directly on web.
Widget renderGoogleButton() => web.renderButton(
  configuration: web.GSIButtonConfiguration(
    theme: web.GSIButtonTheme.outline,
    size: web.GSIButtonSize.large,
    shape: web.GSIButtonShape.pill,
    text: web.GSIButtonText.signinWith,
    logoAlignment: web.GSIButtonLogoAlignment.left,
  ),
);
