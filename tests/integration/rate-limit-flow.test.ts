import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { config } from '@/config/env';

describe('rate limiting', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('starts returning 429 once the auth endpoint limit is exceeded', async () => {
    const attempts = config.authRateLimitMax + 5;
    const statuses: number[] = [];

    for (let i = 0; i < attempts; i++) {
      const res = await ctx.app.inject({
        method: 'POST',
        url: '/api/auth/login',
        payload: { email: 'nobody@example.com', password: 'whatever-password' },
      });
      statuses.push(res.statusCode);
    }

    expect(statuses.filter((s) => s === 429).length).toBeGreaterThan(0);
  });

  it('applies a tighter limit to the money routes', async () => {
    const admin = await createUser(ctx, { admin: true });
    const attempts = config.moneyRateLimitMax + 5;
    const statuses: number[] = [];

    for (let i = 0; i < attempts; i++) {
      const res = await ctx.app.inject({
        method: 'POST',
        url: '/api/payments/confirm',
        headers: authHeader(admin),
        payload: { order_id: '00000000-0000-0000-0000-000000000000' },
      });
      statuses.push(res.statusCode);
    }

    // Well under the global 200/min ceiling, but over the money ceiling.
    expect(attempts).toBeLessThan(config.rateLimitMax);
    expect(statuses.filter((s) => s === 429).length).toBeGreaterThan(0);
  });

  it('puts an x-request-id on every response and honours an inbound one', async () => {
    const minted = await ctx.app.inject({ method: 'GET', url: '/health' });
    expect(minted.headers['x-request-id']).toMatch(/^[0-9a-f-]{36}$/);

    const passed = await ctx.app.inject({
      method: 'GET',
      url: '/health',
      headers: { 'x-request-id': 'trace-abc-123' },
    });
    expect(passed.headers['x-request-id']).toBe('trace-abc-123');
  });
});
