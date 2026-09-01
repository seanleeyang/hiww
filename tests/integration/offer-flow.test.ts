import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createRequest, createTrip } from '../helpers/flows';

describe('offer flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('creates an offer and accepts it into an order', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const traveler = await createUser(ctx, { user_type: 'traveler' });

    const requestId = await createRequest(ctx, shopper);
    const tripId = await createTrip(ctx, traveler);

    const offerResponse = await ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(traveler),
      payload: {
        request_id: requestId,
        quoted_price: '120.00',
        delivery_date: '2026-11-18T10:00:00.000Z',
      },
    });

    expect(offerResponse.statusCode).toBe(201);
    const offerId = offerResponse.json().data.id;

    const acceptedOfferResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/accept`,
      headers: authHeader(shopper),
      payload: {
        trip_id: tripId,
        item_description: 'Luxury skincare set for gifting',
        quantity: 1,
        unit_price: '120.00',
      },
    });

    expect(acceptedOfferResponse.statusCode).toBe(200);
    expect(acceptedOfferResponse.json().success).toBe(true);

    const acceptedOffer = await ctx.db
      .selectFrom('offers')
      .selectAll()
      .where('id', '=', offerId)
      .executeTakeFirst();
    expect(acceptedOffer?.status).toBe('accepted');

    const order = await ctx.db
      .selectFrom('orders')
      .selectAll()
      .where('request_id', '=', requestId)
      .executeTakeFirst();

    expect(order).toBeTruthy();
    expect(order?.trip_id).toBe(tripId);
    expect(order?.status).toBe('pending_payment');
  });

  it('does not let a different shopper accept an offer', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const outsider = await createUser(ctx, { user_type: 'shopper' });

    const requestId = await createRequest(ctx, shopper);
    const tripId = await createTrip(ctx, traveler);

    const offerResponse = await ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(traveler),
      payload: {
        request_id: requestId,
        quoted_price: '120.00',
        delivery_date: '2026-11-18T10:00:00.000Z',
      },
    });
    const offerId = offerResponse.json().data.id;

    const acceptResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/accept`,
      headers: authHeader(outsider),
      payload: {
        trip_id: tripId,
        item_description: 'Luxury skincare set for gifting',
        quantity: 1,
        unit_price: '120.00',
      },
    });

    expect(acceptResponse.statusCode).toBe(403);
  });
});
