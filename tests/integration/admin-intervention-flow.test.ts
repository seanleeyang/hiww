import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, completeOrder } from '../helpers/flows';

describe('admin order intervention (cancel + refund)', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('admin cancels a confirmed order: both parties notified, refund flagged for every admin', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const confirm = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/confirm',
      headers: authHeader(admin),
      payload: { order_id: order.orderId },
    });
    expect(confirm.statusCode).toBe(200);

    const cancel = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/cancel`,
      headers: authHeader(admin),
      payload: { reason: 'Traveler backed out after payment was confirmed' },
    });
    expect(cancel.statusCode).toBe(200);
    expect(cancel.json().data).toMatchObject({ status: 'cancelled', refund_owed: true });

    const shopperNotifs = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(order.shopper),
    });
    const shopperItems = shopperNotifs.json().data.items as Array<{ type: string }>;
    expect(shopperItems.some((n) => n.type === 'order_cancelled')).toBe(true);

    const travelerNotifs = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(order.traveler),
    });
    const travelerItems = travelerNotifs.json().data.items as Array<{ type: string }>;
    expect(travelerItems.some((n) => n.type === 'order_cancelled')).toBe(true);

    const adminNotifs = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(admin),
    });
    const adminItems = adminNotifs.json().data.items as Array<{ type: string }>;
    expect(adminItems.some((n) => n.type === 'refund_due')).toBe(true);

    const reconciliation = await ctx.app.inject({
      method: 'GET',
      url: '/api/ops/reconciliation',
      headers: authHeader(admin),
    });
    const awaitingRefund = reconciliation.json().data.awaiting_refund;
    expect(awaitingRefund.orders.some((o: { id: string }) => o.id === order.orderId)).toBe(true);
  });

  it('admin cancels an order still pending payment: no refund owed, no admin refund_due notice', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const cancel = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/cancel`,
      headers: authHeader(admin),
      payload: { reason: 'Shopper changed their mind before paying' },
    });
    expect(cancel.statusCode).toBe(200);
    expect(cancel.json().data).toMatchObject({ status: 'cancelled', refund_owed: false });

    const adminNotifs = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(admin),
    });
    const adminItems = adminNotifs.json().data.items as Array<{ type: string }>;
    expect(adminItems.some((n) => n.type === 'refund_due')).toBe(false);
  });

  it('cannot cancel an order that has already been paid out', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);

    const payout = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/payout',
      headers: authHeader(admin),
      payload: { order_id: order.orderId, method: 'bank_transfer', reference: 'ref-1' },
    });
    expect(payout.statusCode).toBe(201);

    const cancel = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/cancel`,
      headers: authHeader(admin),
      payload: { reason: 'Too late, trying to cancel after payout anyway' },
    });
    expect(cancel.statusCode).toBe(409);
  });

  it('cannot cancel an order twice', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const first = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/cancel`,
      headers: authHeader(admin),
      payload: { reason: 'First cancellation reason here' },
    });
    expect(first.statusCode).toBe(200);

    const second = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/cancel`,
      headers: authHeader(admin),
      payload: { reason: 'Second cancellation reason here' },
    });
    expect(second.statusCode).toBe(409);
  });

  it('cancelling an order can resolve a linked dispute in the same action', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const disputeRes = await ctx.app.inject({
      method: 'POST',
      url: '/api/disputes',
      headers: authHeader(order.shopper),
      payload: { order_id: order.orderId, reason: 'Traveler wants to cancel after accepting my offer' },
    });
    expect(disputeRes.statusCode).toBe(201);
    const disputeId = disputeRes.json().data.id as string;

    const cancel = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/cancel`,
      headers: authHeader(admin),
      payload: { reason: 'Cancelling the order per the dispute report', dispute_id: disputeId },
    });
    expect(cancel.statusCode).toBe(200);

    // The dispute is no longer open, so it no longer shows up as one requiring a resolve.
    const disputeResolveAttempt = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/disputes/${disputeId}/resolve`,
      headers: authHeader(admin),
      payload: { status: 'resolved', resolution: 'Already resolved via cancellation' },
    });
    expect(disputeResolveAttempt.statusCode).toBe(409);
  });

  it('a non-admin cannot cancel an order', async () => {
    const order = await createAcceptedOrder(ctx);
    const cancel = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/cancel`,
      headers: authHeader(order.shopper),
      payload: { reason: 'Trying to self-serve cancel as a shopper' },
    });
    expect(cancel.statusCode).toBe(403);
  });
});

describe('admin refund recording', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    await closeTestApp(ctx);
  });

  async function cancelledConfirmedOrder(admin: Awaited<ReturnType<typeof createUser>>) {
    const order = await createAcceptedOrder(ctx);
    await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/confirm',
      headers: authHeader(admin),
      payload: { order_id: order.orderId },
    });
    await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/cancel`,
      headers: authHeader(admin),
      payload: { reason: 'Cancelled after confirmed payment for refund testing' },
    });
    return order;
  }

  it('records a refund, notifies the shopper, and moves reconciliation from awaiting to refunded', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await cancelledConfirmedOrder(admin);

    const refund = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/refund`,
      headers: authHeader(admin),
      payload: { method: 'bank_transfer', reference: 'refund-ref-1' },
    });
    expect(refund.statusCode).toBe(201);

    const shopperNotifs = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(order.shopper),
    });
    const items = shopperNotifs.json().data.items as Array<{ type: string }>;
    expect(items.some((n) => n.type === 'refund_sent')).toBe(true);

    const reconciliation = await ctx.app.inject({
      method: 'GET',
      url: '/api/ops/reconciliation',
      headers: authHeader(admin),
    });
    const data = reconciliation.json().data;
    expect(data.awaiting_refund.orders.some((o: { id: string }) => o.id === order.orderId)).toBe(false);
    expect(data.refunded.refunds.some((r: { order_id: string }) => r.order_id === order.orderId)).toBe(true);
  });

  it('cannot refund the same order twice', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await cancelledConfirmedOrder(admin);

    const first = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/refund`,
      headers: authHeader(admin),
      payload: { method: 'bank_transfer', reference: 'refund-ref-1' },
    });
    expect(first.statusCode).toBe(201);

    const second = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/refund`,
      headers: authHeader(admin),
      payload: { method: 'bank_transfer', reference: 'refund-ref-2' },
    });
    expect(second.statusCode).toBe(409);
  });

  it('a concurrent double-refund attempt on the same order records exactly one refund', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await cancelledConfirmedOrder(admin);

    const attempt = (reference: string) =>
      ctx.app.inject({
        method: 'POST',
        url: `/api/admin/orders/${order.orderId}/refund`,
        headers: authHeader(admin),
        payload: { method: 'bank_transfer', reference },
      });
    const [r1, r2] = await Promise.all([attempt('refund-race-1'), attempt('refund-race-2')]);

    const codes = [r1.statusCode, r2.statusCode].sort();
    expect(codes).toEqual([201, 409]);

    const refunds = await ctx.db.selectFrom('refunds').selectAll().where('order_id', '=', order.orderId).execute();
    expect(refunds).toHaveLength(1);
  });

  it('cannot refund an order that was never cancelled', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/confirm',
      headers: authHeader(admin),
      payload: { order_id: order.orderId },
    });

    const refund = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/refund`,
      headers: authHeader(admin),
      payload: { method: 'bank_transfer', reference: 'refund-ref-1' },
    });
    expect(refund.statusCode).toBe(409);
  });

  it('cannot refund a cancelled order that was never actually paid for', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/cancel`,
      headers: authHeader(admin),
      payload: { reason: 'Cancelled while still pending payment' },
    });

    const refund = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/refund`,
      headers: authHeader(admin),
      payload: { method: 'bank_transfer', reference: 'refund-ref-1' },
    });
    expect(refund.statusCode).toBe(409);
  });
});

describe('admin visibility: offers and reviews', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('lists all offers for an admin', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const res = await ctx.app.inject({
      method: 'GET',
      url: '/api/admin/offers',
      headers: authHeader(admin),
    });
    expect(res.statusCode).toBe(200);
    const offers = res.json().data.offers as Array<{ id: string }>;
    expect(offers.some((o) => o.id === order.offerId)).toBe(true);
  });

  it('the dev-tools test-order endpoint produces a real, usable order', async () => {
    const admin = await createUser(ctx, { admin: true });

    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/admin/dev/create-test-order',
      headers: authHeader(admin),
    });
    expect(res.statusCode).toBe(201);
    const orderId = res.json().data.order_id as string;

    const order = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${orderId}`,
      headers: authHeader(admin),
    });
    expect(order.statusCode).toBe(200);
    expect(order.json().data.status).toBe('pending_payment');
  });

  it('a non-admin cannot use the dev-tools test-order endpoint', async () => {
    const plain = await createUser(ctx, { user_type: 'both' });
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/admin/dev/create-test-order',
      headers: authHeader(plain),
    });
    expect(res.statusCode).toBe(403);
  });

  it('admin can hide and unhide a review; hiding removes it from the public list', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);

    const reviewRes = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/review`,
      headers: authHeader(order.shopper),
      payload: { rating: 1, comment: 'Abusive text goes here for moderation testing' },
    });
    expect(reviewRes.statusCode).toBe(201);
    const reviewId = reviewRes.json().data.id as string;

    const listBefore = await ctx.app.inject({
      method: 'GET',
      url: `/api/users/${order.traveler.userId}/reviews`,
    });
    expect(listBefore.json().data.items.some((r: { id: string }) => r.id === reviewId)).toBe(true);

    const hide = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/order-reviews/${reviewId}/hide`,
      headers: authHeader(admin),
    });
    expect(hide.statusCode).toBe(200);

    const listAfterHide = await ctx.app.inject({
      method: 'GET',
      url: `/api/users/${order.traveler.userId}/reviews`,
    });
    expect(listAfterHide.json().data.items.some((r: { id: string }) => r.id === reviewId)).toBe(false);

    const unhide = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/order-reviews/${reviewId}/unhide`,
      headers: authHeader(admin),
    });
    expect(unhide.statusCode).toBe(200);

    const listAfterUnhide = await ctx.app.inject({
      method: 'GET',
      url: `/api/users/${order.traveler.userId}/reviews`,
    });
    expect(listAfterUnhide.json().data.items.some((r: { id: string }) => r.id === reviewId)).toBe(true);
  });
});
