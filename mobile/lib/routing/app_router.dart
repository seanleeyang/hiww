import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/presentation/account_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/discovery/presentation/browse_screen.dart';
import '../features/orders/presentation/confirm_review_screen.dart';
import '../features/orders/presentation/order_chat_placeholder.dart';
import '../features/orders/presentation/order_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/placeholder_tab.dart';
import '../features/shell/splash_screen.dart';
import '../features/trips/presentation/my_trips_screen.dart';
import '../features/trips/presentation/new_trip_screen.dart';
import '../features/trips/presentation/trip_detail_screen.dart';
import '../features/wants/presentation/make_offer_screen.dart';
import '../features/wants/presentation/my_wants_screen.dart';
import '../features/wants/presentation/want_detail_screen.dart';

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
      GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
      GoRoute(
        path: '/trips/new',
        builder: (_, _) => const NewTripScreen(),
      ),
      GoRoute(
        path: '/trips/:id',
        builder: (_, s) => TripDetailScreen(tripId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/wants/:id/offer',
        builder: (_, s) => MakeOfferScreen(wantId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/wants/:id',
        builder: (_, s) => WantDetailScreen(wantId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/orders/:id/confirm',
        builder: (_, s) => ConfirmReviewScreen(
          orderId: s.pathParameters['id']!,
          reviewOnly: s.uri.queryParameters['review'] == '1',
        ),
      ),
      GoRoute(
        path: '/orders/:id/chat',
        builder: (_, _) => const OrderChatPlaceholder(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, s) => OrderScreen(orderId: s.pathParameters['id']!),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/browse', builder: (_, _) => const BrowseScreen()),
          GoRoute(path: '/my-trips', builder: (_, _) => const MyTripsScreen()),
          GoRoute(path: '/my-wants', builder: (_, _) => const MyWantsScreen()),
          GoRoute(
            path: '/inbox',
            builder: (_, _) => const PlaceholderTab(
              tab: ShellTab.inbox,
              blurb: 'Messages with travelers and shoppers about your orders. '
                  'Arriving in the next update.',
            ),
          ),
        ],
      ),
    ],
  );
});
