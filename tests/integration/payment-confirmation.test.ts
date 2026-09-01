import { makeTestApp, closeTestApp, authHeader, createUser, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder } from '../helpers/flows';

describe('payment confirmation (manual-money pilot)', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('an admin records payment, moving the order to confirmed with no ledger entries', async () => {
    const order = await createAcceptedOrder(ctx);
    const admin = await createUser(ctx, { admin: true });

    const response = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/confirm',
      headers: authHeader(admin),
      payload: { order_id: order.orderId, payment_id: 'manual-bank-transfer-ref' },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ success: true, data: { status: 'confirmed', order_id: order.orderId } });

    const row = await ctx.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(row?.status).toBe('confirmed');

    const ledger = await ctx.db
      .selectFrom('ledger_entries')
      .selectAll()
      .where('order_id', '=', order.orderId)
      .execute();
    expect(ledger).toHaveLength(0);
  });

  it('is idempotent: confirming twice does not error or double-process', async () => {
    const order = await createAcceptedOrder(ctx);
    const admin = await createUser(ctx, { admin: true });

    const first = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/confirm',
      headers: authHeader(admin),
      payload: { order_id: order.orderId },
    });
    const second = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/confirm',
      headers: authHeader(admin),
      payload: { order_id: order.orderId },
    });

    expect(first.statusCode).toBe(200);
    expect(second.statusCode).toBe(200);
  });

  it('rejects payment confirmation from a non-admin', async () => {
    const order = await createAcceptedOrder(ctx);

    const response = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/confirm',
      headers: authHeader(order.shopper),
      payload: { order_id: order.orderId },
    });

    expect(response.statusCode).toBe(403);
  });

  it('rejects payment confirmation with no token', async () => {
    const order = await createAcceptedOrder(ctx);

    const response = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/confirm',
      payload: { order_id: order.orderId },
    });

    expect(response.statusCode).toBe(401);
  });
});
