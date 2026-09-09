import { makeTestApp, closeTestApp, createUser, completeProfile, authHeader, type TestContext } from '../helpers/test-app';
import { createTrip } from '../helpers/flows';

describe('"Request from this trip" — direct requests stay private', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  async function setup() {
    const sean = await createUser(ctx, { user_type: 'traveler' });
    const passakorn = await createUser(ctx, { user_type: 'shopper' });
    await completeProfile(ctx, sean);
    await completeProfile(ctx, passakorn);
    const tripId = await createTrip(ctx, sean);
    return { sean, passakorn, tripId };
  }

  it('creates a private want + an auto-opened offer, and notifies the traveler', async () => {
    const { sean, passakorn, tripId } = await setup();

    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/requests',
      headers: authHeader(passakorn),
      payload: {
        item_description: 'Matcha KitKats, the big box',
        source_country: 'JP',
        category: 'food',
        estimated_weight_kg: 1,
        budget: '80.00',
        destination_country: 'TH',
        target_trip_id: tripId,
      },
    });
    expect(res.statusCode).toBe(201);
    expect(res.json().data.offer_id).toBeTruthy();
    const requestId = res.json().data.id as string;
    const offerId = res.json().data.offer_id as string;

    const offerRow = await ctx.db.selectFrom('offers').selectAll().where('id', '=', offerId).executeTakeFirst();
    expect(offerRow?.traveler_id).toBe(sean.userId);
    expect(offerRow?.request_id).toBe(requestId);
    expect(offerRow?.last_actor).toBe('shopper');
    expect(offerRow?.round).toBe(0);
    expect(offerRow?.quoted_price).toBe('80.00');

    const notif = await ctx.db
      .selectFrom('notifications')
      .selectAll()
      .where('user_id', '=', sean.userId)
      .where('type', '=', 'offer_received')
      .executeTakeFirst();
    expect(notif).toBeTruthy();
    expect(notif?.link).toBe(`/wants/${requestId}`);

    // Sean sees it via the normal negotiation surface (my_turn should be true).
    const mine = await ctx.app.inject({ method: 'GET', url: '/api/offers/mine', headers: authHeader(sean) });
    const item = mine.json().data.items.find((o: { id: string }) => o.id === offerId);
    expect(item.my_turn).toBe(true);
  });

  it('is excluded from the public browse feed and discovery feed', async () => {
    const { passakorn, tripId } = await setup();
    const stranger = await createUser(ctx, { user_type: 'traveler' });

    await ctx.app.inject({
      method: 'POST',
      url: '/api/requests',
      headers: authHeader(passakorn),
      payload: {
        item_description: 'A very specific gift only for Sean to bring',
        source_country: 'JP',
        category: 'other',
        estimated_weight_kg: 1,
        budget: '50.00',
        destination_country: 'TH',
        target_trip_id: tripId,
      },
    });

    const browse = await ctx.app.inject({ method: 'GET', url: '/api/requests', headers: authHeader(stranger) });
    expect(
      browse.json().data.items.some((r: { item_description: string }) => r.item_description.includes('very specific gift'))
    ).toBe(false);

    const feed = await ctx.app.inject({ method: 'GET', url: '/api/discover/feed?type=wants', headers: authHeader(stranger) });
    expect(
      feed.json().data.items.some((i: { request?: { item_description?: string } }) =>
        i.request?.item_description?.includes('very specific gift')
      )
    ).toBe(false);
  });

  it('blocks a different traveler from offering on a want targeted at someone else\'s trip', async () => {
    const { passakorn, tripId } = await setup();
    const otherTraveler = await createUser(ctx, { user_type: 'traveler' });
    await completeProfile(ctx, otherTraveler);
    const otherTripId = await createTrip(ctx, otherTraveler);

    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/requests',
      headers: authHeader(passakorn),
      payload: {
        item_description: 'Targeted item',
        source_country: 'JP',
        category: 'other',
        estimated_weight_kg: 1,
        budget: '60.00',
        destination_country: 'TH',
        target_trip_id: tripId,
      },
    });
    const requestId = res.json().data.id as string;

    const hijack = await ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(otherTraveler),
      payload: {
        request_id: requestId,
        trip_id: otherTripId,
        quoted_price: '55.00',
        delivery_date: '2026-11-18T10:00:00.000Z',
      },
    });
    expect(hijack.statusCode).toBe(403);
  });

  it('rejects requesting from your own trip', async () => {
    const { sean, tripId } = await setup();
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/requests',
      headers: authHeader(sean),
      payload: {
        item_description: 'Should not work',
        source_country: 'JP',
        category: 'other',
        estimated_weight_kg: 1,
        budget: '40.00',
        destination_country: 'TH',
        target_trip_id: tripId,
      },
    });
    expect(res.statusCode).toBe(403);
  });

  it('lets the traveler accept the shopper\'s opening price directly, creating an order', async () => {
    const { sean, tripId } = await setup();
    const passakorn = await createUser(ctx, { user_type: 'shopper' });
    await completeProfile(ctx, passakorn);

    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/requests',
      headers: authHeader(passakorn),
      payload: {
        item_description: 'Ready to buy at asking price',
        source_country: 'JP',
        category: 'other',
        estimated_weight_kg: 1,
        budget: '70.00',
        destination_country: 'TH',
        target_trip_id: tripId,
      },
    });
    const offerId = res.json().data.offer_id as string;

    const accept = await ctx.app.inject({ method: 'POST', url: `/api/offers/${offerId}/accept`, headers: authHeader(sean), payload: {} });
    expect(accept.statusCode).toBe(200);
    expect(accept.json().data.order_id).toBeTruthy();
  });
});
