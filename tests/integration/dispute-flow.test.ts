import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, forceOrderStatus } from '../helpers/flows';

describe('dispute flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('lets a participant open a dispute and an admin resolve it', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'confirmed');
    const admin = await createUser(ctx, { admin: true });

    const disputeResponse = await ctx.app.inject({
      method: 'POST',
      url: '/api/disputes',
      headers: authHeader(order.shopper),
      payload: { order_id: order.orderId, reason: 'Item arrived damaged and late' },
    });

    expect(disputeResponse.statusCode).toBe(201);
    const disputeId = disputeResponse.json().data.id;

    const resolutionResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/disputes/${disputeId}/resolve`,
      headers: authHeader(admin),
      payload: {
        resolution: 'Partial refund approved due to delay and damage.',
        status: 'resolved',
      },
    });

    expect(resolutionResponse.statusCode).toBe(200);
    expect(resolutionResponse.json().success).toBe(true);

    const dispute = await ctx.db
      .selectFrom('disputes')
      .selectAll()
      .where('id', '=', disputeId)
      .executeTakeFirst();

    expect(dispute?.status).toBe('resolved');
    expect(dispute?.resolution).toContain('Partial refund');
  });

  it('does not let a non-admin resolve a dispute', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'confirmed');

    const disputeResponse = await ctx.app.inject({
      method: 'POST',
      url: '/api/disputes',
      headers: authHeader(order.shopper),
      payload: { order_id: order.orderId, reason: 'Item arrived damaged and late' },
    });
    const disputeId = disputeResponse.json().data.id;

    const resolutionResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/disputes/${disputeId}/resolve`,
      headers: authHeader(order.traveler),
      payload: { resolution: 'I decided to close my own dispute.', status: 'resolved' },
    });

    expect(resolutionResponse.statusCode).toBe(403);
  });

  it('does not let a stranger open a dispute on an order', async () => {
    const order = await createAcceptedOrder(ctx);
    const outsider = await createUser(ctx, { user_type: 'both' });

    const disputeResponse = await ctx.app.inject({
      method: 'POST',
      url: '/api/disputes',
      headers: authHeader(outsider),
      payload: { order_id: order.orderId, reason: 'I want in on this order somehow' },
    });

    expect(disputeResponse.statusCode).toBe(403);
  });
});
