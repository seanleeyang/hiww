import 'package:flutter/material.dart';

/// Stub for the web-only Google sign-in button, since `google_sign_in_web`
/// has to be behind a conditional import.
Widget renderGoogleButton({required double width, required String locale}) =>
    throw StateError('renderGoogleButton is web-only');
