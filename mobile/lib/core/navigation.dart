import 'package:flutter/widgets.dart';

/// Lets code without a local [BuildContext] (notably [ApiClient], which maps
/// every failed request) reach the current navigator — used to show the
/// "Before You Proceed" verification prompt from wherever a
/// VERIFICATION_REQUIRED error happens to surface.
final rootNavigatorKey = GlobalKey<NavigatorState>();
