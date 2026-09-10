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
    await forceOrderStatus(ctx, order.orderId, 'purchased');

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
      payload: { note: 'Received package', image_url: 'https://example.com/delivery-proof.jpg' },
    });

    expect(releaseResponse.statusCode).toBe(200);
    const finalOrder = await ctx.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(finalOrder?.status).toBe('delivered');
    expect(finalOrder?.delivery_proof_url).toBe('https://example.com/delivery-proof.jpg');

    // Manual-money pilot: no funds move through these routes.
    const ledger = await ctx.db
      .selectFrom('ledger_entries')
      .selectAll()
      .where('order_id', '=', order.orderId)
      .execute();
    expect(ledger).toHaveLength(0);
  });

  it('stores optional shipping proof when the traveler provides one', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'purchased');

    const deliverResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/deliver`,
      headers: authHeader(order.traveler),
      payload: { shipping_proof_url: 'https://example.com/grabbike.jpg' },
    });

    expect(deliverResponse.statusCode).toBe(200);
    const afterDelivery = await ctx.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(afterDelivery?.status).toBe('in_transit');
    expect(afterDelivery?.shipping_proof_url).toBe('https://example.com/grabbike.jpg');
  });

  it('marking shipped without proof still works — it is optional, not required', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'purchased');

    const deliverResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/deliver`,
      headers: authHeader(order.traveler),
      payload: {},
    });

    expect(deliverResponse.statusCode).toBe(200);
    const afterDelivery = await ctx.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(afterDelivery?.status).toBe('in_transit');
    expect(afterDelivery?.shipping_proof_url).toBeNull();
  });

  it('lets the traveler add shipping proof after the fact, while still in_transit', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'purchased');
    await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/deliver`,
      headers: authHeader(order.traveler),
      payload: {},
    });

    const addProof = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/shipping-proof`,
      headers: authHeader(order.traveler),
      payload: { image_url: 'https://example.com/grabbike-late.jpg' },
    });

    expect(addProof.statusCode).toBe(200);
    const row = await ctx.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(row?.shipping_proof_url).toBe('https://example.com/grabbike-late.jpg');
  });

  it('rejects adding shipping proof before the order has shipped', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'purchased');

    const addProof = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/shipping-proof`,
      headers: authHeader(order.traveler),
      payload: { image_url: 'https://example.com/too-early.jpg' },
    });

    expect(addProof.statusCode).toBe(409);
  });

  it('rejects the shopper adding shipping proof — traveler only', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'purchased');
    await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/deliver`,
      headers: authHeader(order.traveler),
      payload: {},
    });

    const addProof = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/shipping-proof`,
      headers: authHeader(order.shopper),
      payload: { image_url: 'https://example.com/not-yours.jpg' },
    });

    expect(addProof.statusCode).toBe(403);
  });

  it('requires a delivery photo before releasing payment', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'purchased');
    await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/deliver`,
      headers: authHeader(order.traveler),
      payload: {},
    });

    const noPhoto = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/release`,
      headers: authHeader(order.shopper),
      payload: { note: 'Received it' },
    });
    expect(noPhoto.statusCode).toBe(400);

    const stillInTransit = await ctx.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(stillInTransit?.status).toBe('in_transit');

    const withPhoto = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/release`,
      headers: authHeader(order.shopper),
      payload: { image_url: 'https://example.com/proof.jpg' },
    });
    expect(withPhoto.statusCode).toBe(200);
  });

  it('is idempotent: releasing an already-delivered order stays delivered', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'purchased');

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
      payload: { image_url: 'https://example.com/delivery-proof.jpg' },
    });
    // Repeat call with no photo — already delivered, so it's a no-op and
    // doesn't re-check the required-photo rule.
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

  it('requires a purchase receipt before shipping', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'confirmed');

    // Can't ship straight from confirmed any more.
    const early = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/deliver`,
      headers: authHeader(order.traveler),
      payload: {},
    });
    expect(early.statusCode).toBe(409);

    // Only the traveler can upload it.
    const wrongUploader = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/purchase-proof`,
      headers: authHeader(order.shopper),
      payload: { image_url: 'https://example.com/r.jpg' },
    });
    expect(wrongUploader.statusCode).toBe(403);

    // A URL is required.
    const noUrl = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/purchase-proof`,
      headers: authHeader(order.traveler),
      payload: {},
    });
    expect(noUrl.statusCode).toBe(400);

    const proof = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/purchase-proof`,
      headers: authHeader(order.traveler),
      payload: { image_url: 'https://example.com/receipt.jpg', note: 'bought at Bic Camera' },
    });
    expect(proof.statusCode).toBe(200);

    const afterProof = await ctx.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(afterProof?.status).toBe('purchased');
    expect(afterProof?.purchase_proof_url).toBe('https://example.com/receipt.jpg');
    expect(afterProof?.purchased_at).not.toBeNull();

    // Now shipping works.
    const ship = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/deliver`,
      headers: authHeader(order.traveler),
      payload: {},
    });
    expect(ship.statusCode).toBe(200);
  });

  it('only the traveler can mark delivered, only the shopper can confirm receipt', async () => {
    const order = await createAcceptedOrder(ctx);
    await forceOrderStatus(ctx, order.orderId, 'purchased');

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
