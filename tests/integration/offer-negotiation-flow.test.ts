import { makeTestApp, closeTestApp, createUser, completeProfile, authHeader, type TestContext } from '../helpers/test-app';
import { createRequest, createTrip } from '../helpers/flows';

async function setup(ctx: TestContext) {
  const shopper = await createUser(ctx, { user_type: 'shopper' });
  const traveler = await createUser(ctx, { user_type: 'traveler' });
  await completeProfile(ctx, shopper);
  await completeProfile(ctx, traveler);
  const requestId = await createRequest(ctx, shopper);
  const tripId = await createTrip(ctx, traveler);

  const offerRes = await ctx.app.inject({
    method: 'POST',
    url: '/api/offers',
    headers: authHeader(traveler),
    payload: {
      request_id: requestId,
      trip_id: tripId,
      quoted_price: '100.00',
      delivery_date: '2026-11-18T10:00:00.000Z',
    },
  });
  const offerId = offerRes.json().data.id as string;
  return { shopper, traveler, requestId, tripId, offerId };
}

describe('offer negotiation: counter-offers capped at 2 rounds', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('starts at round 0 with the traveler as last_actor', async () => {
    const { shopper, requestId } = await setup(ctx);
    const res = await ctx.app.inject({ method: 'GET', url: `/api/requests/${requestId}/offers`, headers: authHeader(shopper) });
    const offer = res.json().data.items[0];
    expect(offer.round).toBe(0);
    expect(offer.last_actor).toBe('traveler');
    expect(offer.my_turn).toBe(true);
    expect(offer.can_counter).toBe(true);
  });

  it('lets the shopper accept the initial offer outright, creating an order', async () => {
    const { shopper, offerId } = await setup(ctx);
    const res = await ctx.app.inject({ method: 'POST', url: `/api/offers/${offerId}/accept`, headers: authHeader(shopper), payload: {} });
    expect(res.statusCode).toBe(200);
    expect(res.json().data.order_id).toBeTruthy();
  });

  it('blocks the traveler from accepting their own still-standing offer', async () => {
    const { traveler, offerId } = await setup(ctx);
    const res = await ctx.app.inject({ method: 'POST', url: `/api/offers/${offerId}/accept`, headers: authHeader(traveler), payload: {} });
    expect(res.statusCode).toBe(409);
  });

  it('runs a full negotiation to the round cap, then blocks a third counter', async () => {
    const { shopper, traveler, offerId } = await setup(ctx);

    // Round 1: shopper counters at 120.
    const c1 = await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/counter`,
      headers: authHeader(shopper),
      payload: { quoted_price: '120.00' },
    });
    expect(c1.statusCode).toBe(200);
    expect(c1.json().data.round).toBe(1);
    expect(c1.json().data.can_counter).toBe(true);

    // Shopper can't counter their own standing offer again.
    const selfCounter = await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/counter`,
      headers: authHeader(shopper),
      payload: { quoted_price: '125.00' },
    });
    expect(selfCounter.statusCode).toBe(409);

    // Round 2: traveler counters at 110 — cap reached.
    const c2 = await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/counter`,
      headers: authHeader(traveler),
      payload: { quoted_price: '110.00' },
    });
    expect(c2.statusCode).toBe(200);
    expect(c2.json().data.round).toBe(2);
    expect(c2.json().data.can_counter).toBe(false);

    // A third counter (by the shopper, whose turn it is) is blocked.
    const c3 = await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/counter`,
      headers: authHeader(shopper),
      payload: { quoted_price: '115.00' },
    });
    expect(c3.statusCode).toBe(409);
    expect(c3.json().error).toMatch(/limit/i);

    // The shopper can still accept the last price (110) though.
    const accept = await ctx.app.inject({ method: 'POST', url: `/api/offers/${offerId}/accept`, headers: authHeader(shopper), payload: {} });
    expect(accept.statusCode).toBe(200);

    const offerRow = await ctx.db.selectFrom('offers').selectAll().where('id', '=', offerId).executeTakeFirst();
    expect(offerRow?.quoted_price).toBe('110.00');
    expect(Array.isArray(offerRow?.price_history)).toBe(true);
    expect(offerRow?.price_history).toHaveLength(3);

    const order = await ctx.db.selectFrom('orders').selectAll().where('offer_id', '=', offerId).executeTakeFirst();
    expect(order?.total_price).toBe('110');
  });

  it('notifies the shopper when the traveler is the one who accepts', async () => {
    const { shopper, traveler, offerId } = await setup(ctx);
    await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/counter`,
      headers: authHeader(shopper),
      payload: { quoted_price: '90.00' },
    });
    const accept = await ctx.app.inject({ method: 'POST', url: `/api/offers/${offerId}/accept`, headers: authHeader(traveler), payload: {} });
    expect(accept.statusCode).toBe(200);

    const notif = await ctx.db
      .selectFrom('notifications')
      .selectAll()
      .where('user_id', '=', shopper.userId)
      .where('type', '=', 'offer_accepted')
      .executeTakeFirst();
    expect(notif).toBeTruthy();
    expect(notif?.body).toMatch(/pay within/i);
  });

  it('lets either side decline outright, leaving the want open for others', async () => {
    const { shopper, offerId, requestId } = await setup(ctx);
    const decline = await ctx.app.inject({ method: 'POST', url: `/api/offers/${offerId}/reject`, headers: authHeader(shopper), payload: {} });
    expect(decline.statusCode).toBe(200);

    const offerRow = await ctx.db.selectFrom('offers').select(['status']).where('id', '=', offerId).executeTakeFirst();
    expect(offerRow?.status).toBe('rejected');

    const req = await ctx.db.selectFrom('requests').select(['status']).where('id', '=', requestId).executeTakeFirst();
    expect(req?.status).toBe('open');
  });

  it('blocks declining your own still-standing offer', async () => {
    const { traveler, offerId } = await setup(ctx);
    const res = await ctx.app.inject({ method: 'POST', url: `/api/offers/${offerId}/reject`, headers: authHeader(traveler), payload: {} });
    expect(res.statusCode).toBe(409);
  });

  it('lists a negotiation for both sides via GET /api/offers/negotiations, role-aware', async () => {
    const { shopper, traveler, offerId } = await setup(ctx);
    await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/counter`,
      headers: authHeader(shopper),
      payload: { quoted_price: '90.00' },
    });

    const asTraveler = await ctx.app.inject({ method: 'GET', url: '/api/offers/negotiations', headers: authHeader(traveler) });
    expect(asTraveler.statusCode).toBe(200);
    const travelerView = asTraveler.json().data.items.find((o: { id: string }) => o.id === offerId);
    expect(travelerView.my_role).toBe('traveler');
    expect(travelerView.my_turn).toBe(true);
    expect(travelerView.counterparty_name).toBeTruthy();

    const asShopper = await ctx.app.inject({ method: 'GET', url: '/api/offers/negotiations', headers: authHeader(shopper) });
    const shopperView = asShopper.json().data.items.find((o: { id: string }) => o.id === offerId);
    expect(shopperView.my_role).toBe('shopper');
    expect(shopperView.my_turn).toBe(false);
    expect(shopperView.counterparty_name).toBeTruthy();

    // A stranger sees neither side of it.
    const stranger = await createUser(ctx, { user_type: 'both' });
    const asStranger = await ctx.app.inject({ method: 'GET', url: '/api/offers/negotiations', headers: authHeader(stranger) });
    expect(asStranger.json().data.items.some((o: { id: string }) => o.id === offerId)).toBe(false);
  });

  it('auto-expires an offer nobody responded to in time', async () => {
    const { shopper, traveler, offerId } = await setup(ctx);
    await ctx.db
      .updateTable('offers')
      .set({ respond_by: new Date(Date.now() - 60_000) })
      .where('id', '=', offerId)
      .execute();

    const res = await ctx.app.inject({ method: 'GET', url: '/api/offers/mine', headers: authHeader(traveler) });
    expect(res.statusCode).toBe(200);
    const offer = res.json().data.items.find((o: { id: string }) => o.id === offerId);
    expect(offer.status).toBe('expired');

    const auditRow = await ctx.db
      .selectFrom('audit_log')
      .selectAll()
      .where('action', '=', 'offer.expire')
      .where('target_id', '=', offerId)
      .executeTakeFirst();
    expect(auditRow).toBeTruthy();

    const shopperNotif = await ctx.db
      .selectFrom('notifications')
      .selectAll()
      .where('user_id', '=', shopper.userId)
      .where('type', '=', 'offer_expired')
      .executeTakeFirst();
    expect(shopperNotif).toBeTruthy();
  });
});
