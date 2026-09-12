import { makeTestApp, closeTestApp, type TestContext } from '../helpers/test-app';

/**
 * Unlike ADMIN_ROUTES (see admin-route-gating.test.ts), there is no single
 * exported list of "just needs to be logged in" routes to walk exhaustively
 * — that's the default for everything not explicitly listed in
 * PUBLIC_ROUTES/PUBLIC_GET_ROUTES (src/middleware/auth-guard.ts). This is a
 * representative backstop instead: one route per major module, proving the
 * base "no token, no access" rule actually holds in practice rather than
 * only in the allowlist's own logic. A route that's accidentally added to
 * PUBLIC_ROUTES (or a brand-new module that forgets the guard applies at
 * all) would still slip past this — it's a sample, not a census — but it
 * catches the guard itself regressing, which is the failure mode that
 * actually matters (a single global hook, so a break here breaks
 * everything at once).
 */
const PROTECTED_ROUTES: Array<{ method: 'GET' | 'POST'; url: string }> = [
  { method: 'GET', url: '/api/me' },
  { method: 'GET', url: '/api/orders' },
  { method: 'GET', url: '/api/notifications' },
  { method: 'POST', url: '/api/trips' },
  { method: 'POST', url: '/api/requests' },
];

describe('ordinary protected routes reject an unauthenticated caller', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it.each(PROTECTED_ROUTES)('$method $url rejects a request with no token at all', async ({ method, url }) => {
    const res = await ctx.app.inject({ method, url, payload: method === 'POST' ? {} : undefined });
    expect(res.statusCode).toBe(401);
    expect(res.json().code).toBe('AUTH_REQUIRED');
  });

  it.each(PROTECTED_ROUTES)('$method $url rejects a garbage/expired bearer token the same way', async ({ method, url }) => {
    const res = await ctx.app.inject({
      method,
      url,
      headers: { authorization: 'Bearer this-is-not-a-real-token' },
      payload: method === 'POST' ? {} : undefined,
    });
    expect(res.statusCode).toBe(401);
    expect(res.json().code).toBe('AUTH_REQUIRED');
  });
});
