import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { ADMIN_ROUTES } from '@/middleware/auth-guard';

/**
 * ADMIN_ROUTES (src/middleware/auth-guard.ts) is a hardcoded allowlist,
 * decoupled from route registration — a renamed or newly-added admin route
 * that isn't added here silently fails open (becomes an ordinary
 * authenticated request, not an error). This test is the backstop: it walks
 * every current entry and proves a non-admin actually gets 403, so drift
 * shows up as a test failure instead of a silent gap. The auth-guard's admin
 * check runs in a preHandler, before any route-specific validation, so a
 * placeholder id and an empty body are enough — the 403 fires first
 * regardless of whether the resource exists or the payload is valid.
 */
const GET_ROUTES = new Set([
  '/api/admin/reviews',
  '/api/admin/users',
  '/api/admin/audit',
  '/api/admin/trips',
  '/api/admin/requests',
  '/api/admin/offers',
  '/api/admin/order-reviews',
  '/api/ledger/:userId',
  '/api/ops/overview',
  '/api/ops/reconciliation',
]);

const PLACEHOLDER_ID = '00000000-0000-0000-0000-000000000000';

function urlFor(pattern: string): string {
  return pattern.replace(/:[a-zA-Z]+/g, PLACEHOLDER_ID);
}

describe('every ADMIN_ROUTES entry actually rejects a non-admin', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it.each([...ADMIN_ROUTES])('%s', async (pattern) => {
    const plain = await createUser(ctx, { user_type: 'both' });
    const method = GET_ROUTES.has(pattern) ? 'GET' : 'POST';

    const res = await ctx.app.inject({
      method,
      url: urlFor(pattern),
      headers: authHeader(plain),
      payload: method === 'POST' ? {} : undefined,
    });

    expect(res.statusCode).toBe(403);
    expect(res.json().code).toBe('ADMIN_REQUIRED');
  });
});
