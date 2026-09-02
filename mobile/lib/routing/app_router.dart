import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/account/presentation/account_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/placeholder_tab.dart';
import '../features/shell/splash_screen.dart';

/// Bridges Riverpod changes into a [Listenable] that go_router can refresh on.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/browse',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/register';

      if (auth.isLoading && auth.valueOrNull == null) {
        return loc == '/splash' ? null : '/splash';
      }

      final signedIn = auth.valueOrNull is AuthSignedIn;
      if (!signedIn) return onAuthPage ? null : '/login';
      if (onAuthPage || loc == '/splash') return '/browse';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/account',
        builder: (_, _) => const AccountScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/browse',
            builder: (_, _) => const PlaceholderTab(
              tab: ShellTab.browse,
              blurb:
                  'A feed of travelers and the things people want bought abroad. '
                  'Arriving in the next update.',
            ),
          ),
          GoRoute(
            path: '/my-trips',
            builder: (_, _) => const PlaceholderTab(
              tab: ShellTab.trips,
              blurb: 'Post a trip and see what shoppers want on your route.',
            ),
          ),
          GoRoute(
            path: '/my-wants',
            builder: (_, _) => const PlaceholderTab(
              tab: ShellTab.wants,
              blurb: 'Post what you want bought and review traveler offers.',
            ),
          ),
          GoRoute(
            path: '/inbox',
            builder: (_, _) => const PlaceholderTab(
              tab: ShellTab.inbox,
              blurb: 'Messages with travelers and shoppers about your orders.',
            ),
          ),
        ],
      ),
    ],
  );
});
