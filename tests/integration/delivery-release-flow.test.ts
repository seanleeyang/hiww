import { makeTestApp, closeTestApp, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, forceOrderStatus } from '../helpers/flows';

describe('delivery and release flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('marks delivery and confirms receipt without minting ledger entries', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'confirmed');

    const deliverResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/deliver`,
      headers: authHeader(order.traveler),
      payload: { note: 'Package delivered at destination' },
    });

    expect(deliverResponse.statusCode).toBe(200);
    const afterDelivery = await ctx.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(afterDelivery?.status).toBe('in_transit');

    const releaseResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/release`,
      headers: authHeader(order.shopper),
      payload: { note: 'Received package' },
    });

    expect(releaseResponse.statusCode).toBe(200);
    const finalOrder = await ctx.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(finalOrder?.status).toBe('delivered');

    // Manual-money pilot: no funds move through these routes.
    const ledger = await ctx.db
      .selectFrom('ledger_entries')
      .selectAll()
      .where('order_id', '=', order.orderId)
      .execute();
    expect(ledger).toHaveLength(0);
  });

  it('is idempotent: releasing an already-delivered order stays delivered', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'confirmed');

    await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/deliver`,
      headers: authHeader(order.traveler),
      payload: {},
    });
    const first = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/release`,
      headers: authHeader(order.shopper),
      payload: {},
    });
    const second = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/release`,
      headers: authHeader(order.shopper),
      payload: {},
    });

    expect(first.statusCode).toBe(200);
    expect(second.statusCode).toBe(200);
    const finalOrder = await ctx.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(finalOrder?.status).toBe('delivered');
  });

  it('only the traveler can mark delivered, only the shopper can confirm receipt', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'confirmed');

    const wrongDeliver = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/deliver`,
      headers: authHeader(order.shopper),
      payload: {},
    });
    expect(wrongDeliver.statusCode).toBe(403);

    await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/deliver`,
      headers: authHeader(order.traveler),
      payload: {},
    });

    const wrongRelease = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/release`,
      headers: authHeader(order.traveler),
      payload: {},
    });
    expect(wrongRelease.statusCode).toBe(403);
  });
});
