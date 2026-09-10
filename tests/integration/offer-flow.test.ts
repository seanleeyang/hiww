import { makeTestApp, closeTestApp, createUser, completeProfile, authHeader, type TestContext } from '../helpers/test-app';
import { createRequest, createTrip } from '../helpers/flows';

describe('offer flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  async function makeOffer(traveler: Awaited<ReturnType<typeof createUser>>, requestId: string, tripId: string, price = '120.00') {
    return ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(traveler),
      payload: { request_id: requestId, trip_id: tripId, quoted_price: price, delivery_date: '2026-11-18T10:00:00.000Z' },
    });
  }

  it('creates an offer and accepts it into an order derived from the request', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    await completeProfile(ctx, shopper);
    await completeProfile(ctx, traveler);
    const requestId = await createRequest(ctx, shopper);
    const tripId = await createTrip(ctx, traveler);

    const offerRes = await makeOffer(traveler, requestId, tripId, '120.00');
    expect(offerRes.statusCode).toBe(201);
    const offerId = offerRes.json().data.id;

    const acceptRes = await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/accept`,
      headers: authHeader(shopper),
      payload: {},
    });
    expect(acceptRes.statusCode).toBe(200);
    const orderId = acceptRes.json().data.order_id;

    const order = await ctx.db.selectFrom('orders').selectAll().where('id', '=', orderId).executeTakeFirst();
    expect(order?.status).toBe('pending_payment');
    expect(order?.trip_id).toBe(tripId);
    expect(order?.total_price).toBe('120');
    // 10% of ฿120 is ฿12, below the ฿50 reward floor, so the floor applies.
    expect(order?.fees).toBe('12');
    expect(order?.traveller_reward).toBe('50');
    expect(order?.shopper_total).toBe('182');
    expect(order?.traveller_payout).toBe('170');
    expect(order?.currency).toBe('THB');

    const req = await ctx.db.selectFrom('requests').selectAll().where('id', '=', requestId).executeTakeFirst();
    expect(req?.status).toBe('accepted');
  });

  it('a concurrent double-accept creates exactly one order, not two', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    await completeProfile(ctx, shopper);
    await completeProfile(ctx, traveler);
    const requestId = await createRequest(ctx, shopper);
    const tripId = await createTrip(ctx, traveler);
    const offerId = (await makeOffer(traveler, requestId, tripId)).json().data.id;

    const accept = () =>
      ctx.app.inject({
        method: 'POST',
        url: `/api/offers/${offerId}/accept`,
        headers: authHeader(shopper),
        payload: {},
      });
    const [r1, r2] = await Promise.all([accept(), accept()]);

    const codes = [r1.statusCode, r2.statusCode].sort();
    expect(codes).toEqual([200, 409]);

    const orders = await ctx.db.selectFrom('orders').selectAll().where('offer_id', '=', offerId).execute();
    expect(orders).toHaveLength(1);
  });

  it('rejects the other pending offers when one is accepted', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const t1 = await createUser(ctx, { user_type: 'traveler' });
    const t2 = await createUser(ctx, { user_type: 'traveler' });
    await completeProfile(ctx, shopper);
    await completeProfile(ctx, t1);
    await completeProfile(ctx, t2);
    const requestId = await createRequest(ctx, shopper);
    const trip1 = await createTrip(ctx, t1);
    const trip2 = await createTrip(ctx, t2);

    const o1 = (await makeOffer(t1, requestId, trip1, '100.00')).json().data.id;
    const o2 = (await makeOffer(t2, requestId, trip2, '130.00')).json().data.id;

    await ctx.app.inject({ method: 'POST', url: `/api/offers/${o1}/accept`, headers: authHeader(shopper), payload: {} });

    const losing = await ctx.db.selectFrom('offers').select('status').where('id', '=', o2).executeTakeFirst();
    expect(losing?.status).toBe('rejected');
  });

  it('does not let a traveler offer on their own request, or use a trip that is not theirs', async () => {
    const shopper = await createUser(ctx, { user_type: 'both' });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    await completeProfile(ctx, shopper);
    await completeProfile(ctx, traveler);
    const requestId = await createRequest(ctx, shopper);
    const shopperTrip = await createTrip(ctx, shopper);
    const travelerTrip = await createTrip(ctx, traveler);

    // shopper offering on their own request
    const own = await makeOffer(shopper, requestId, shopperTrip);
    expect(own.statusCode).toBe(403);

    // traveler using the shopper's trip
    const wrongTrip = await makeOffer(traveler, requestId, shopperTrip);
    expect(wrongTrip.statusCode).toBe(403);

    // valid
    const ok = await makeOffer(traveler, requestId, travelerTrip);
    expect(ok.statusCode).toBe(201);
  });

  it('does not let a different shopper accept an offer', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const outsider = await createUser(ctx, { user_type: 'shopper' });
    await completeProfile(ctx, traveler);
    const requestId = await createRequest(ctx, shopper);
    const tripId = await createTrip(ctx, traveler);

    const offerId = (await makeOffer(traveler, requestId, tripId)).json().data.id;

    const acceptResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/accept`,
      headers: authHeader(outsider),
      payload: {},
    });
    expect(acceptResponse.statusCode).toBe(403);
  });

  it('lets a shopper see offers on their request; a traveler sees only their own', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const t1 = await createUser(ctx, { user_type: 'traveler' });
    const t2 = await createUser(ctx, { user_type: 'traveler' });
    await completeProfile(ctx, t1);
    await completeProfile(ctx, t2);
    const requestId = await createRequest(ctx, shopper);
    const trip1 = await createTrip(ctx, t1);
    const trip2 = await createTrip(ctx, t2);
    await makeOffer(t1, requestId, trip1, '100.00');
    await makeOffer(t2, requestId, trip2, '130.00');

    const asOwner = await ctx.app.inject({ method: 'GET', url: `/api/requests/${requestId}/offers`, headers: authHeader(shopper) });
    expect(asOwner.json().data.items.length).toBe(2);

    const asTraveler = await ctx.app.inject({ method: 'GET', url: `/api/requests/${requestId}/offers`, headers: authHeader(t1) });
    expect(asTraveler.json().data.items.length).toBe(1);
  });
});
