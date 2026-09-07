import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder } from '../helpers/flows';

async function setDeadlineInPast(ctx: TestContext, orderId: string): Promise<void> {
  await ctx.db
    .updateTable('orders')
    .set({ payment_deadline_at: new Date(Date.now() - 60_000) })
    .where('id', '=', orderId)
    .execute();
}

describe('payment timeout auto-cancels an unpaid order', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('sets a payment_deadline_at when an offer is accepted', async () => {
    const order = await createAcceptedOrder(ctx);
    const row = await ctx.db.selectFrom('orders').select(['payment_deadline_at']).where('id', '=', order.orderId).executeTakeFirst();
    expect(row?.payment_deadline_at).toBeTruthy();
    expect(new Date(row!.payment_deadline_at!).getTime()).toBeGreaterThan(Date.now());
  });

  it('auto-cancels the order, reopens the want, and expires the offer once the deadline passes', async () => {
    const order = await createAcceptedOrder(ctx);
    await setDeadlineInPast(ctx, order.orderId);

    const res = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}`,
      headers: authHeader(order.shopper),
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().data.status).toBe('cancelled');
    expect(res.json().data.cancelled_at).toBeTruthy();

    const req = await ctx.db.selectFrom('requests').select(['status']).where('id', '=', order.requestId).executeTakeFirst();
    expect(req?.status).toBe('open');

    const offer = await ctx.db.selectFrom('offers').select(['status']).where('id', '=', order.offerId).executeTakeFirst();
    expect(offer?.status).toBe('expired');

    const audit = await ctx.db
      .selectFrom('audit_log')
      .selectAll()
      .where('action', '=', 'order.payment_timeout')
      .where('target_id', '=', order.orderId)
      .executeTakeFirst();
    expect(audit).toBeTruthy();

    const shopperNotif = await ctx.db
      .selectFrom('notifications')
      .selectAll()
      .where('user_id', '=', order.shopper.userId)
      .where('type', '=', 'payment_timeout')
      .executeTakeFirst();
    expect(shopperNotif).toBeTruthy();
    const travelerNotif = await ctx.db
      .selectFrom('notifications')
      .selectAll()
      .where('user_id', '=', order.traveler.userId)
      .where('type', '=', 'payment_timeout')
      .executeTakeFirst();
    expect(travelerNotif).toBeTruthy();
  });

  it('rejects a late claim-payment on an order that already expired', async () => {
    const order = await createAcceptedOrder(ctx);
    await setDeadlineInPast(ctx, order.orderId);

    const res = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/claim-payment`,
      headers: authHeader(order.shopper),
    });
    expect(res.statusCode).toBe(409);
    expect(res.json().error).toMatch(/cancelled/i);
  });

  it('does not expire an order the shopper already claimed payment on', async () => {
    const order = await createAcceptedOrder(ctx);

    const claim = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/claim-payment`,
      headers: authHeader(order.shopper),
    });
    expect(claim.statusCode).toBe(200);

    await setDeadlineInPast(ctx, order.orderId);

    const res = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}`,
      headers: authHeader(order.shopper),
    });
    expect(res.json().data.status).toBe('pending_payment');
  });

  it('lets a fresh offer be made on the reopened want after expiry', async () => {
    const order = await createAcceptedOrder(ctx);
    await setDeadlineInPast(ctx, order.orderId);

    // Trigger expiry via any order-touching route.
    await ctx.app.inject({ method: 'GET', url: '/api/orders', headers: authHeader(order.shopper) });

    const newTraveler = await createUser(ctx, { user_type: 'traveler' });
    const trip = await ctx.app.inject({
      method: 'POST',
      url: '/api/trips',
      headers: authHeader(newTraveler),
      payload: {
        departure_country: 'US',
        arrival_country: 'FR',
        departure_date: '2026-11-15T08:00:00.000Z',
        return_date: '2026-11-22T08:00:00.000Z',
        max_weight_kg: 25,
        max_items: 3,
      },
    });
    await ctx.db
      .updateTable('users')
      .set({ phone: '+1 555 0100', address_street: '1 Main', address_city: 'X', address_postal_code: '1', address_country: 'US' })
      .where('id', '=', newTraveler.userId)
      .execute();

    const offerRes = await ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(newTraveler),
      payload: {
        request_id: order.requestId,
        trip_id: trip.json().data.id,
        quoted_price: '50.00',
        delivery_date: '2026-11-18T10:00:00.000Z',
      },
    });
    expect(offerRes.statusCode).toBe(201);
  });
});
