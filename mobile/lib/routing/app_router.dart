import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/presentation/account_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/line_callback_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/verify_otp_screen.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/presentation/inbox_screen.dart';
import '../features/chat/presentation/order_chat_screen.dart';
import '../features/auth/presentation/landing_screen.dart';
import '../features/discovery/data/discovery_repository.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/discovery/presentation/browse_screen.dart';
import '../features/onboarding/application/onboarding_controller.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/orders/data/orders_repository.dart';
import '../features/orders/presentation/confirm_review_screen.dart';
import '../features/orders/presentation/my_orders_screen.dart';
import '../features/orders/presentation/order_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shared/data/reviews_repository.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/splash_screen.dart';
import '../features/trips/data/trips_repository.dart';
import '../features/trips/domain/trip.dart';
import '../features/trips/presentation/my_trips_screen.dart';
import '../features/trips/presentation/new_trip_screen.dart';
import '../features/trips/presentation/trip_detail_screen.dart';
import '../features/wants/data/offers_repository.dart';
import '../features/wants/data/wants_repository.dart';
import '../features/wants/presentation/make_offer_screen.dart';
import '../features/wants/presentation/want_detail_screen.dart';

/// Bridges Riverpod changes into a [Listenable] that go_router can refresh on.
/// Also the single place that clears every user-scoped data cache when the
/// signed-in identity changes — otherwise Riverpod keeps serving whatever the
/// previous account fetched (e.g. account B's "My wants" showing account A's
/// wants after switching accounts in the same tab/session).
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(onboardingSeenProvider, (_, _) => notifyListeners());
    ref.listen(authControllerProvider, (previous, next) {
      final previousId = _userId(previous);
      final nextId = _userId(next);
      if (previousId != nextId) {
        ref.invalidate(myWantsProvider);
        ref.invalidate(wantDetailProvider);
        ref.invalidate(wantOffersProvider);
        ref.invalidate(orderProvider);
        ref.invalidate(orderIdByRequestProvider);
        ref.invalidate(myPublishedTripsProvider);
        ref.invalidate(tripDetailProvider);
        ref.invalidate(notificationsProvider);
        ref.invalidate(inboxProvider);
        ref.invalidate(feedProvider);
        ref.invalidate(routeMatchProvider);
        ref.invalidate(userReviewsProvider);
        ref.invalidate(myOffersProvider);
        ref.invalidate(negotiationsProvider);
      }
      notifyListeners();
    });
  }

  static String? _userId(AsyncValue<AuthState>? state) {
    final value = state?.valueOrNull;
    return value is AuthSignedIn ? value.user.id : null;
  }
}

/// A guest (signed-out, no account) may only *view* a few read-only routes —
/// Browse, and one trip/want's detail page. Every action route (post/edit/
/// offer/order/chat/account/…) still requires signing in. `/trips/new` and
/// `/wants/new` each look like they could match their sibling `:id` shape
/// but must not — excluded explicitly.
bool _isGuestViewableRoute(String loc) {
  if (loc == '/browse') return true;
  if (RegExp(r'^/trips/(?!new$)[^/]+$').hasMatch(loc)) return true;
  if (RegExp(r'^/wants/(?!new$)[^/]+$').hasMatch(loc)) return true;
  return false;
}

const _preAuthRoutes = {
  '/landing',
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
  '/line-callback',
};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/landing',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      if (auth.isLoading && auth.valueOrNull == null) {
        return loc == '/splash' ? null : '/splash';
      }

      final signedInState = auth.valueOrNull;
      if (signedInState is AuthSignedIn) {
        final onVerifyPage = loc == '/verify';
        if (signedInState.user.needsVerification) {
          return onVerifyPage ? null : '/verify';
        }
        final onPreAuthPage = _preAuthRoutes.contains(loc) || loc == '/onboarding';
        if (onPreAuthPage || loc == '/splash' || onVerifyPage) return '/browse';
        return null;
      }

      // Signed out. Treat an unresolved onboarding-seen read as "seen"
      // (fail open) rather than blocking navigation on it — if it turns out
      // to be unseen, `_AuthRefresh`'s listener re-runs this the moment it
      // resolves and bounces to `/onboarding` a beat later.
      final seenOnboarding = ref.read(onboardingSeenProvider).valueOrNull ?? true;
      if (!seenOnboarding) {
        return loc == '/onboarding' ? null : '/onboarding';
      }
      if (loc == '/onboarding') return '/landing'; // already seen; skip if reached directly
      if (_preAuthRoutes.contains(loc)) return null;
      if (_isGuestViewableRoute(loc)) return null;
      return '/landing';
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/landing', builder: (_, _) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/line-callback',
        builder: (_, s) => LineCallbackScreen(
          code: s.uri.queryParameters['code'],
          state: s.uri.queryParameters['state'],
          error: s.uri.queryParameters['error'],
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, s) => ResetPasswordScreen(
          email: s.uri.queryParameters['email'] ?? '',
          devCode: s.uri.queryParameters['devCode'],
        ),
      ),
      GoRoute(path: '/verify', builder: (_, _) => const VerifyOtpScreen()),
      GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/trips/new',
        builder: (_, s) {
          final prefill = s.extra as TripQuickPrefill?;
          return NewTripScreen(
            prefillFromCountry: prefill?.fromCountry,
            prefillFromCity: prefill?.fromCity,
            prefillToCountry: prefill?.toCountry,
            prefillToCity: prefill?.toCity,
            prefillDepart: prefill?.depart,
            prefillReturn: prefill?.ret,
          );
        },
      ),
      GoRoute(
        path: '/trips/:id/edit',
        builder: (_, s) => NewTripScreen(existing: s.extra as Trip),
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
        builder: (_, s) => OrderChatScreen(orderId: s.pathParameters['id']!),
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
          GoRoute(
            path: '/my-orders',
            builder: (_, _) => const MyOrdersScreen(),
          ),
          GoRoute(path: '/inbox', builder: (_, _) => const InboxScreen()),
        ],
      ),
    ],
  );
});
