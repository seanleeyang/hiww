import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, completeOrder } from '../helpers/flows';

interface Notif {
  id: string;
  type: string;
  subject: string;
  body: string;
  order_id: string | null;
  link: string | null;
  read_at: string | null;
  created_at: string;
}

describe('notifications feed', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  const feed = async (user: Parameters<typeof authHeader>[0]) => {
    const res = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(user),
    });
    expect(res.statusCode).toBe(200);
    return res.json().data as { items: Notif[]; unread_count: number };
  };

  it('requires auth', async () => {
    const res = await ctx.app.inject({ method: 'GET', url: '/api/notifications' });
    expect(res.statusCode).toBe(401);
  });

  it('notifies the shopper when a traveler makes an offer', async () => {
    const order = await createAcceptedOrder(ctx); // makes then accepts an offer

    const shopper = await feed(order.shopper);
    const received = shopper.items.find((n) => n.type === 'offer_received');
    expect(received).toBeDefined();
    expect(received!.link).toBe(`/wants/${order.requestId}`);
  });

  it('notifies the traveler when their offer is accepted, linking to the order', async () => {
    const order = await createAcceptedOrder(ctx);

    const traveler = await feed(order.traveler);
    const accepted = traveler.items.find((n) => n.type === 'offer_accepted');
    expect(accepted).toBeDefined();
    expect(accepted!.order_id).toBe(order.orderId);
    expect(accepted!.link).toBe(`/orders/${order.orderId}`);
    expect(traveler.unread_count).toBeGreaterThanOrEqual(1);

    // The shopper who did the accepting doesn't get that one.
    const shopper = await feed(order.shopper);
    expect(shopper.items.some((n) => n.type === 'offer_accepted')).toBe(false);
  });

  it('notifies the shopper when the traveler uploads a purchase receipt', async () => {
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order); // includes the purchase-proof step

    const shopper = await feed(order.shopper);
    expect(shopper.items.some((n) => n.type === 'purchase_proof')).toBe(true);
    // the traveler doesn't get notified about their own upload
    const traveler = await feed(order.traveler);
    expect(traveler.items.some((n) => n.type === 'purchase_proof')).toBe(false);
  });

  it('notifies both parties through the full happy path', async () => {
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order); // confirm payment → ship → release

    const shopper = await feed(order.shopper);
    const traveler = await feed(order.traveler);

    // payment confirmed → both
    expect(shopper.items.some((n) => n.type === 'payment_confirmed')).toBe(true);
    expect(traveler.items.some((n) => n.type === 'payment_confirmed')).toBe(true);
    // shipped → shopper only
    expect(shopper.items.some((n) => n.type === 'shipped')).toBe(true);
    expect(traveler.items.some((n) => n.type === 'shipped')).toBe(false);
    // delivered → both
    expect(shopper.items.some((n) => n.type === 'delivered')).toBe(true);
    expect(traveler.items.some((n) => n.type === 'delivered')).toBe(true);

    // newest first
    const times = shopper.items.map((n) => new Date(n.created_at).getTime());
    expect([...times].sort((a, b) => b - a)).toEqual(times);
  });

  it('marks one, then all, as read', async () => {
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);

    let shopper = await feed(order.shopper);
    const before = shopper.unread_count;
    expect(before).toBeGreaterThan(1);

    const one = shopper.items[0].id;
    await ctx.app.inject({
      method: 'POST',
      url: '/api/notifications/read',
      headers: authHeader(order.shopper),
      payload: { id: one },
    });
    shopper = await feed(order.shopper);
    expect(shopper.unread_count).toBe(before - 1);
    expect(shopper.items.find((n) => n.id === one)!.read_at).not.toBeNull();

    await ctx.app.inject({
      method: 'POST',
      url: '/api/notifications/read',
      headers: authHeader(order.shopper),
      payload: {},
    });
    shopper = await feed(order.shopper);
    expect(shopper.unread_count).toBe(0);
  });

  it('notifies the traveler on payout', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);

    await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/payout',
      headers: authHeader(admin),
      payload: { order_id: order.orderId, amount: '120.00', method: 'wise', reference: 'W-9' },
    });

    const traveler = await feed(order.traveler);
    const payout = traveler.items.find((n) => n.type === 'payout_sent');
    expect(payout).toBeDefined();
    expect(payout!.body).toContain('W-9');
  });

  it('notifies the counterparty when a dispute is opened, and both when resolved', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);

    const opened = await ctx.app.inject({
      method: 'POST',
      url: '/api/disputes',
      headers: authHeader(order.shopper),
      payload: { order_id: order.orderId, reason: 'One item was missing from the parcel' },
    });
    const disputeId = opened.json().data.id as string;

    let traveler = await feed(order.traveler);
    expect(traveler.items.some((n) => n.type === 'dispute_opened')).toBe(true);
    let shopper = await feed(order.shopper);
    expect(shopper.items.some((n) => n.type === 'dispute_opened')).toBe(false);

    await ctx.app.inject({
      method: 'POST',
      url: `/api/disputes/${disputeId}/resolve`,
      headers: authHeader(admin),
      payload: { status: 'resolved', resolution: 'Refunded the shopper 20.00, noted in the sheet.' },
    });

    traveler = await feed(order.traveler);
    shopper = await feed(order.shopper);
    expect(traveler.items.some((n) => n.type === 'dispute_resolved')).toBe(true);
    expect(shopper.items.some((n) => n.type === 'dispute_resolved')).toBe(true);
  });
});
