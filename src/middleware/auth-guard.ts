import { FastifyInstance, FastifyRequest } from 'fastify';
import { AppError } from '@/utils/helpers';
import { verifyToken } from '@/utils/auth';

/**
 * Routes that do not require a logged-in user. Everything else is protected by
 * default — a request with no valid bearer token is rejected before it reaches
 * the handler.
 */
const PUBLIC_ROUTES = new Set<string>([
  '/health',
  '/api/auth/register',
  '/api/auth/login',
  '/api/auth/social',
  '/api/auth/forgot-password',
  '/api/auth/reset-password',
  '/',
  '/app',
  '/admin',
  // Static serving of user-uploaded images (@fastify/static wildcard route).
  '/uploads/*',
]);

/**
 * Read-only routes a signed-out guest can browse — see the mobile app's
 * guest-mode routing in `app_router.dart`. Checked only for GET: several of
 * these path patterns (`/api/trips/:id`, `/api/requests/:id`) are shared with
 * PATCH/DELETE handlers on the same route, which must stay auth-required.
 */
const PUBLIC_GET_ROUTES = new Set<string>([
  '/api/discover/feed',
  '/api/trips/:id',
  '/api/requests/:id',
  '/api/users/:id/reviews',
]);

/**
 * Reachable by a logged-in but not-yet-verified user, so they can see their
 * status, verify, or ask for a new code. Everything else needs both
 * `email_verified_at` and `phone_verified_at` set (see the register route,
 * `src/services/otp/`).
 */
const VERIFICATION_EXEMPT_ROUTES = new Set<string>([
  '/api/auth/verify-otp',
  '/api/auth/resend-otp',
]);

/** Same idea, but only for GET — `PATCH /api/me` (editing a profile field)
 * still requires full verification, only *seeing* your own status doesn't. */
const VERIFICATION_EXEMPT_GET_ROUTES = new Set<string>(['/api/me']);

/**
 * Routes that require `users.role = 'admin'`. These are the staff-only controls:
 * moving money, reviewing KYC, resolving disputes, flagging accounts and
 * reading operational dashboards.
 */
// Exported so tests/integration/admin-route-gating.test.ts can assert every
// entry is actually 403'd for a non-admin — the fragile part of this
// allowlist design is that a route renamed/added without a matching entry
// here silently fails open (becomes an ordinary authenticated request, no
// error), so that test is the backstop that catches drift.
export const ADMIN_ROUTES = new Set<string>([
  '/api/admin/reviews',
  '/api/admin/users',
  '/api/admin/audit',
  '/api/admin/disputes/:id/resolve',
  '/api/admin/users/:userId/kyc-review',
  '/api/admin/users/:userId/flag',
  '/api/admin/orders/:id/clear-receipt-flag',
  '/api/admin/messages/:id/clear-flag',
  '/api/admin/trips',
  '/api/admin/trips/:id/remove',
  '/api/admin/trips/remove-all',
  '/api/admin/requests',
  '/api/admin/requests/:id/remove',
  '/api/admin/requests/remove-all',
  '/api/admin/orders/:id/cancel',
  '/api/admin/orders/:id/refund',
  '/api/admin/offers',
  '/api/admin/order-reviews',
  '/api/admin/order-reviews/:id/hide',
  '/api/admin/order-reviews/:id/unhide',
  '/api/admin/dev/create-test-order',
  '/api/compliance/kyc/approve',
  '/api/disputes/:id/resolve',
  '/api/ledger/:userId',
  '/api/payments/initiate',
  '/api/payments/confirm',
  '/api/payments/payout',
  '/api/ops/overview',
  '/api/ops/reconciliation',
]);

function matchedRoute(request: FastifyRequest): string | undefined {
  const fromOptions = request.routeOptions?.url;
  if (fromOptions) {
    return fromOptions;
  }
  // Fallback for older Fastify internals.
  return (request as unknown as { routerPath?: string }).routerPath;
}

export async function registerAuthGuard(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', async (request) => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const req = request as any;
    req.userId = undefined;
    req.userRole = undefined;

    const authHeader = request.headers.authorization;
    if (typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
      try {
        const payload = verifyToken(authHeader.slice(7));
        req.userId = payload.userId;
      } catch {
        // Invalid or expired token: treat as unauthenticated. No `x-user-id`
        // fallback — the only way to be a user is to present a valid token.
      }
    }

    const routeUrl = matchedRoute(request);
    if (!routeUrl || PUBLIC_ROUTES.has(routeUrl)) {
      return;
    }
    if (request.method === 'GET' && PUBLIC_GET_ROUTES.has(routeUrl)) {
      return;
    }

    if (!req.userId) {
      throw new AppError('AUTH_REQUIRED', 401, 'common.authRequired');
    }

    // Resolve the caller's role once so downstream handlers can make ownership
    // vs admin decisions without another lookup.
    const actor = await req.db
      .selectFrom('users')
      .select(['id', 'role', 'email_verified_at', 'phone_verified_at'])
      .where('id', '=', req.userId)
      .executeTakeFirst();
    req.userRole = actor?.role ?? undefined;

    if (ADMIN_ROUTES.has(routeUrl) && req.userRole !== 'admin') {
      throw new AppError('ADMIN_REQUIRED', 403, 'authGuard.adminRequired');
    }

    const verificationExempt =
      VERIFICATION_EXEMPT_ROUTES.has(routeUrl) ||
      (request.method === 'GET' && VERIFICATION_EXEMPT_GET_ROUTES.has(routeUrl));
    if (!verificationExempt && (!actor?.email_verified_at || !actor?.phone_verified_at)) {
      throw new AppError('VERIFICATION_REQUIRED', 403, 'authGuard.verificationRequired');
    }
  });
}
