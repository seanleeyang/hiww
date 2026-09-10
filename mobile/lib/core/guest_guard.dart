import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';

/// Guards an action a signed-out guest could otherwise trigger without ever
/// hitting a route the router can redirect (e.g. opening a bottom sheet).
/// Returns true and does nothing when signed in; when signed out, sends the
/// guest to `/landing` instead and returns false so the caller can bail out.
///
/// Carries the page the guest was on as `returnTo` so that, once they sign
/// in, the router sends them back to the trip/want they were looking at
/// instead of dropping them on the generic Browse feed — see
/// `app_router.dart`'s redirect and `LandingScreen`/`LoginScreen`/
/// `RegisterScreen`, which all forward it along.
bool requireSignedIn(BuildContext context, WidgetRef ref) {
  if (ref.read(currentUserProvider) != null) return true;
  final returnTo = GoRouterState.of(context).uri.toString();
  context.push('/landing?returnTo=${Uri.encodeComponent(returnTo)}');
  return false;
}
