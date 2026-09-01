import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder } from '../helpers/flows';

describe('ops flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('returns overview metrics for an admin', async () => {
    await createAcceptedOrder(ctx);
    const admin = await createUser(ctx, { admin: true });

    const response = await ctx.app.inject({
      method: 'GET',
      url: '/api/ops/overview',
      headers: authHeader(admin),
    });

    expect(response.statusCode).toBe(200);
    expect(response.json().success).toBe(true);
    expect(response.json().data.users).toBeGreaterThanOrEqual(2);
    expect(response.json().data.orders).toBeGreaterThanOrEqual(1);
  });

  it('is not accessible to a normal user', async () => {
    const user = await createUser(ctx, { user_type: 'both' });
    const response = await ctx.app.inject({
      method: 'GET',
      url: '/api/ops/overview',
      headers: authHeader(user),
    });
    expect(response.statusCode).toBe(403);
  });
});
