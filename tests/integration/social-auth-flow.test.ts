import { makeTestApp, closeTestApp, type TestContext } from '../helpers/test-app';

describe('POST /api/auth/social', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('is reachable without an Authorization header (it IS the login)', async () => {
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/social',
      payload: { provider: 'google', token: 'whatever' },
    });
    // Not 401 — the auth guard must not gate this route, whatever it decides
    // about the token itself.
    expect(res.statusCode).not.toBe(401);
  });

  it('rejects a malformed payload', async () => {
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/social',
      payload: { provider: 'not-a-real-provider', token: '' },
    });
    expect(res.statusCode).toBe(400);
    expect(res.json().code).toBe('VALIDATION_ERROR');
  });

  it('501s a provider with no configured credentials, rather than crashing', async () => {
    // GOOGLE_CLIENT_ID is unset in the test environment by default, and
    // apple/facebook/line have no verification implemented yet at all.
    for (const provider of ['google', 'apple', 'facebook', 'line']) {
      const res = await ctx.app.inject({
        method: 'POST',
        url: '/api/auth/social',
        payload: { provider, token: 'whatever' },
      });
      expect(res.statusCode).toBe(501);
      expect(res.json().code).toBe('NOT_IMPLEMENTED');
    }
  });
});
