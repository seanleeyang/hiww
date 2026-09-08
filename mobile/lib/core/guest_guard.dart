import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';

/// Guards an action a signed-out guest could otherwise trigger without ever
/// hitting a route the router can redirect (e.g. opening a bottom sheet).
/// Returns true and does nothing when signed in; when signed out, sends the
/// guest to `/landing` instead and returns false so the caller can bail out.
bool requireSignedIn(BuildContext context, WidgetRef ref) {
  if (ref.read(currentUserProvider) != null) return true;
  context.push('/landing');
  return false;
}
