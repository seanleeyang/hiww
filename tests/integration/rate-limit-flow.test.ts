import { makeTestApp, closeTestApp, type TestContext } from '../helpers/test-app';
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
});
