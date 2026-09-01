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
  '/',
  '/admin',
  '/console.js',
]);

/**
 * Routes that require `users.role = 'admin'`. These are the staff-only controls:
 * moving money, reviewing KYC, resolving disputes, flagging accounts and
 * reading operational dashboards.
 */
const ADMIN_ROUTES = new Set<string>([
  '/api/admin/reviews',
  '/api/admin/users',
  '/api/admin/disputes/:id/resolve',
  '/api/admin/users/:userId/kyc-review',
  '/api/admin/users/:userId/flag',
  '/api/compliance/kyc/approve',
  '/api/disputes/:id/resolve',
  '/api/ledger/:userId',
  '/api/payments/initiate',
  '/api/payments/confirm',
  '/api/ops/overview',
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

    if (!req.userId) {
      throw new AppError('AUTH_REQUIRED', 401, 'Authentication required');
    }

    // Resolve the caller's role once so downstream handlers can make ownership
    // vs admin decisions without another lookup.
    const actor = await req.db
      .selectFrom('users')
      .select(['id', 'role'])
      .where('id', '=', req.userId)
      .executeTakeFirst();
    req.userRole = actor?.role ?? undefined;

    if (ADMIN_ROUTES.has(routeUrl) && req.userRole !== 'admin') {
      throw new AppError('ADMIN_REQUIRED', 403, 'Administrator access required');
    }
  });
}
