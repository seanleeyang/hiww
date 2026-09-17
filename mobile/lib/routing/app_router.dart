import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation.dart';
import '../features/account/presentation/account_screen.dart';
import '../features/account/presentation/change_contact_screen.dart';
import '../features/account/presentation/change_password_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/facebook_callback_screen.dart';
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
  bool minSplashElapsed = false;
  late final Ticker _minSplashTicker;

  _AuthRefresh(Ref ref) {
    // Re-run the redirect once _minSplashDuration has elapsed, in case auth
    // already resolved before then — see that constant's doc comment. A
    // Ticker (not a plain Timer) so this correctly advances under widget
    // tests' simulated frame clock too — pumpAndSettle() only keeps
    // advancing time while frames are being scheduled, which a bare Timer
    // doesn't do, but a Ticker (the same primitive AnimationController
    // itself uses) does.
    _minSplashTicker = Ticker((elapsed) {
      if (elapsed < _minSplashDuration) return;
      minSplashElapsed = true;
      _minSplashTicker.stop();
      notifyListeners();
    })
      ..start();
    ref.onDispose(_minSplashTicker.dispose);
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
        ref.invalidate(myOrdersProvider);
        ref.invalidate(myPublishedTripsProvider);
        ref.invalidate(myTripsProvider);
        ref.invalidate(tripDetailProvider);
        ref.invalidate(notificationsProvider);
        ref.invalidate(inboxProvider);
        ref.invalidate(orderMessagesProvider);
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

/// Matches the ~2s Loading/Reveal/Complete breakdown measured from Wise's
/// own launch recording: ~0.6s static splash, ~0.8s tear, ~0.6s settle
/// (the destination's content fading/scaling in only once the tear is
/// fully done, not simultaneously with it — see _tornOpenPage).
const _minSplashDuration = Duration(milliseconds: 600);
const _tearMs = 800;
const _settleMs = 600;
const _launchTransitionDuration = Duration(milliseconds: _tearMs + _settleMs);
// The tear's own share of the combined tear+settle timeline that
// _launchTransitionDuration drives — see _tornOpenPage.
const _tearShare = _tearMs / (_tearMs + _settleMs);

/// The exact visual /splash shows (solid Tangelo, mark centered) — shared
/// with _tornOpenPage's overlay below so the tear reads as "this same
/// screen ripping apart," not a different graphic.
class _SplashVisual extends StatelessWidget {
  const _SplashVisual();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFFB4D00),
      child: Center(
        child: Image(image: AssetImage('assets/images/hiww_mark_white.png'), width: 56),
      ),
    );
  }
}

/// How many horizontal slices the tear is built from. Each slice's left
/// and right halves separate on their own staggered schedule (see
/// _tornOpenPage) — more slices makes the diagonal rip line smoother.
const _tearStripCount = 16;

/// How much of the total animation each individual strip's own separation
/// takes, as a fraction — the remainder is how staggered strip start times
/// are across the full bottom-to-top sweep.
const _tearStripSpan = 0.45;

/// Wraps [child] in a page that enters by tearing a copy of the splash
/// visual open along a vertical seam that rips upward from the bottom-
/// middle to the top-middle — like Wise's launch animation — revealing
/// [child] beneath it. [child] itself only fades and scales in *after* the
/// tear finishes (the "settle" beat — see _launchTransitionDuration),
/// rather than sitting fully visible under the tear from frame one: what
/// the tear reveals as it opens is the bare Linen background, matching how
/// Wise's own reveal shows its background art first and its text/buttons
/// only once that finishes expanding.
///
/// Built from horizontal strips rather than one rigid left/right pair so
/// the split visibly *travels* up the screen instead of the whole seam
/// opening at once: each strip separates on its own schedule, staggered by
/// height (bottom strips first) via [_tearStripSpan]. The varying
/// per-strip separation amount also gives the seam a naturally irregular,
/// torn-paper silhouette without needing an explicit jagged path.
///
/// This bakes the "fake splash" overlay into the *incoming* page rather
/// than animating the real outgoing SplashScreen's exit: Flutter always
/// paints the incoming page on top of the outgoing one during a route
/// transition, so an effect on the outgoing page's own exit would be
/// layered *underneath* the new page and never actually visible — the
/// tear has to live here to be seen at all.
Page<void> _tornOpenPage(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: _launchTransitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return Stack(
        children: [
          const ColoredBox(color: Color(0xFFFAE8DD)),
          AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) {
              final settleT =
                  ((animation.value - _tearShare) / (1 - _tearShare)).clamp(0.0, 1.0);
              final eased = Curves.easeOut.transform(settleT);
              return Opacity(
                opacity: eased,
                child: Transform.scale(scale: 0.97 + 0.03 * eased, child: child),
              );
            },
          ),
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = (animation.value / _tearShare).clamp(0.0, 1.0);
              if (t >= 1) return const SizedBox.shrink();
              final size = MediaQuery.sizeOf(context);
              final stripHeight = size.height / _tearStripCount;
              final halfWidth = size.width / 2;
              final strips = <Widget>[];
              for (var i = 0; i < _tearStripCount; i++) {
                // f: 0 at the top strip, 1 at the bottom strip — the bottom
                // starts separating at t=0, the top only in the final
                // _tearStripSpan share of the animation.
                final f = (i + 0.5) / _tearStripCount;
                final start = (1 - f) * (1 - _tearStripSpan);
                final localT =
                    ((t - start) / _tearStripSpan).clamp(0.0, 1.0);
                final dx = halfWidth * 1.15 * Curves.easeIn.transform(localT);
                final top = i * stripHeight;
                strips.add(_tearStrip(
                  size: size,
                  top: top,
                  height: stripHeight,
                  left: 0,
                  width: halfWidth,
                  contentOffset: Offset(-dx, -top),
                ));
                strips.add(_tearStrip(
                  size: size,
                  top: top,
                  height: stripHeight,
                  left: halfWidth,
                  width: halfWidth,
                  contentOffset: Offset(-halfWidth + dx, -top),
                ));
              }
              return Stack(children: strips);
            },
          ),
        ],
      );
    },
  );
}

/// One slice of the tearing splash visual: a [width]x[height] window at
/// ([left], [top]) showing the full [size]d _SplashVisual shifted by
/// [contentOffset] — the shift both selects which slice of the visual
/// shows through this window (aligning it to (0,0)) and carries the
/// tear's own separation distance.
Widget _tearStrip({
  required Size size,
  required double top,
  required double height,
  required double left,
  required double width,
  required Offset contentOffset,
}) {
  return Positioned(
    left: left,
    top: top,
    width: width,
    height: height,
    child: ClipRect(
      child: Transform.translate(
        offset: contentOffset,
        child: SizedBox(width: size.width, height: size.height, child: const _SplashVisual()),
      ),
    ),
  );
}

const _preAuthRoutes = {
  '/landing',
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
  '/line-callback',
  '/facebook-callback',
};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/landing',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      final authLoading = auth.isLoading && auth.valueOrNull == null;
      if (authLoading || !refresh.minSplashElapsed) {
        return loc == '/splash' ? null : '/splash';
      }

      final signedInState = auth.valueOrNull;
      if (signedInState is AuthSignedIn) {
        final onPreAuthPage = _preAuthRoutes.contains(loc) || loc == '/onboarding';
        if (onPreAuthPage || loc == '/splash') {
          // Send the guest back to the trip/want/order they were looking at
          // when they were prompted to sign in, if any — see guest_guard.dart
          // and LandingScreen/LoginScreen/RegisterScreen, which set and carry
          // this. Falls back to Browse for a plain "Log in" tap with nothing
          // to return to, or if the value looks unsafe (must be an internal
          // path, and not another pre-auth page — never redirect in a loop).
          final returnTo = state.uri.queryParameters['returnTo'];
          if (returnTo != null &&
              returnTo.startsWith('/') &&
              !_preAuthRoutes.contains(Uri.parse(returnTo).path)) {
            return returnTo;
          }
          return '/browse';
        }
        // Unverified users browse freely rather than being force-redirected
        // here — a gated action shows a "Before You Proceed" prompt instead
        // (see ApiClient's VERIFICATION_REQUIRED interception). /verify is
        // reached on demand via that prompt's Continue button, so only
        // bounce away from it once there's nothing left to verify.
        final onVerifyPage = loc == '/verify';
        if (onVerifyPage && !signedInState.user.needsVerification) return '/browse';
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
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, state) => _tornOpenPage(state.pageKey, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/landing',
        pageBuilder: (_, state) => _tornOpenPage(state.pageKey, const LandingScreen()),
      ),
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
        path: '/facebook-callback',
        builder: (_, s) => FacebookCallbackScreen(
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
      GoRoute(
        path: '/account/change-phone',
        builder: (_, _) => const ChangeContactScreen(channel: ContactChannel.phone),
      ),
      GoRoute(
        path: '/account/change-email',
        builder: (_, _) => const ChangeContactScreen(channel: ContactChannel.email),
      ),
      GoRoute(
        path: '/account/change-password',
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/trips/:id/edit',
        builder: (_, s) => EditTripScreen(existing: s.extra as Trip),
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
        builder: (_, s) => ConfirmReviewScreen(orderId: s.pathParameters['id']!),
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
