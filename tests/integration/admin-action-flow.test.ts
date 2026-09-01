import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, forceOrderStatus } from '../helpers/flows';

describe('admin action flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('lets an admin resolve disputes, review KYC and flag risky users', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'confirmed');
    const admin = await createUser(ctx, { admin: true });

    const disputeCreate = await ctx.app.inject({
      method: 'POST',
      url: '/api/disputes',
      headers: authHeader(order.shopper),
      payload: { order_id: order.orderId, reason: 'Package arrived damaged and no refund was issued' },
    });
    const disputeId = disputeCreate.json().data.id;

    const disputeResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/disputes/${disputeId}/resolve`,
      headers: authHeader(admin),
      payload: { status: 'resolved', resolution: 'Refund approved after packaging inspection showed damage' },
    });
    expect(disputeResponse.statusCode).toBe(200);

    const kycResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/users/${order.shopper.userId}/kyc-review`,
      headers: authHeader(admin),
      payload: { status: 'approved', note: 'Documents verified successfully' },
    });
    expect(kycResponse.statusCode).toBe(200);

    const flagResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/users/${order.shopper.userId}/flag`,
      headers: authHeader(admin),
      payload: { risk_status: 'flagged', reason: 'Repeated refund requests' },
    });
    expect(flagResponse.statusCode).toBe(200);

    const updatedUser = await ctx.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', order.shopper.userId)
      .executeTakeFirst();

    expect(updatedUser?.kyc_status).toBe('approved');
    expect(updatedUser?.risk_status).toBe('flagged');
  });

  it('rejects all admin actions for a non-admin', async () => {
    const attacker = await createUser(ctx, { user_type: 'both' });
    const victim = await createUser(ctx, { user_type: 'both' });

    const flagResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/users/${victim.userId}/flag`,
      headers: authHeader(attacker),
      payload: { risk_status: 'clear', reason: 'unflag myself' },
    });

    expect(flagResponse.statusCode).toBe(403);
  });
});
