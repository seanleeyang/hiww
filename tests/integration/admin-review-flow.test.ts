import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, forceOrderStatus } from '../helpers/flows';

describe('admin review flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('returns a combined review queue of disputes and pending KYC for an admin', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'confirmed');
    const admin = await createUser(ctx, { admin: true });

    await ctx.app.inject({
      method: 'POST',
      url: '/api/disputes',
      headers: authHeader(order.shopper),
      payload: { order_id: order.orderId, reason: 'Order arrived damaged and did not match description' },
    });

    const response = await ctx.app.inject({
      method: 'GET',
      url: '/api/admin/reviews',
      headers: authHeader(admin),
    });

    expect(response.statusCode).toBe(200);
    expect(response.json().success).toBe(true);
    expect(response.json().data.queue.some((item: { type: string }) => item.type === 'dispute')).toBe(true);
    expect(response.json().data.queue.some((item: { type: string }) => item.type === 'kyc')).toBe(true);
  });

  it('is not accessible to a normal user', async () => {
    const user = await createUser(ctx, { user_type: 'both' });
    const response = await ctx.app.inject({
      method: 'GET',
      url: '/api/admin/reviews',
      headers: authHeader(user),
    });
    expect(response.statusCode).toBe(403);
  });
});
