import { makeTestApp, closeTestApp, createUser, completeProfile, authHeader, type TestContext } from '../helpers/test-app';
import { createRequest, createTrip } from '../helpers/flows';

describe('request delivery address', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  async function makeOfferAndAccept(shopper: Awaited<ReturnType<typeof createUser>>, requestId: string) {
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    await completeProfile(ctx, traveler);
    const tripId = await createTrip(ctx, traveler);
    const offerRes = await ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(traveler),
      payload: { request_id: requestId, trip_id: tripId, quoted_price: '120.00', delivery_date: '2026-11-18T10:00:00.000Z' },
    });
    const offerId = offerRes.json().data.id;
    const acceptRes = await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/accept`,
      headers: authHeader(shopper),
      payload: {},
    });
    expect(acceptRes.statusCode).toBe(200);
    return { orderId: acceptRes.json().data.order_id as string, traveler };
  }

  it('defaults to "same as registered address" and never requires the extra fields', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    await completeProfile(ctx, shopper);
    const requestId = await createRequest(ctx, shopper);

    const row = await ctx.db.selectFrom('requests').selectAll().where('id', '=', requestId).executeTakeFirst();
    expect(row?.delivery_same_as_registered).toBe(true);
    expect(row?.delivery_address_street).toBeNull();
  });

  it('requires a street address and postal code when delivery_same_as_registered is false', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    await completeProfile(ctx, shopper);

    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/requests',
      headers: authHeader(shopper),
      payload: {
        item_description: 'Luxury skincare set for gifting',
        source_country: 'US',
        category: 'beauty',
        estimated_weight_kg: 2,
        budget: '150.00',
        destination_country: 'TH',
        delivery_same_as_registered: false,
      },
    });
    expect(res.statusCode).toBe(400);
  });

  it('never exposes the delivery address on the public browse feed, even to an admin', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    await completeProfile(ctx, shopper);
    await createRequest(ctx, shopper, {
      delivery_same_as_registered: false,
      delivery_address_street: '99 Secret Soi',
      delivery_address_postal_code: '10110',
    });

    const admin = await createUser(ctx, { admin: true });
    const res = await ctx.app.inject({ method: 'GET', url: '/api/requests', headers: authHeader(admin) });
    expect(res.statusCode).toBe(200);
    const items = res.json().data.items as Record<string, unknown>[];
    expect(items.length).toBeGreaterThan(0);
    for (const item of items) {
      expect(item.delivery_address_street).toBeUndefined();
      expect(item.delivery_same_as_registered).toBeUndefined();
    }
  });

  it('shows the delivery address on the detail route to its own shopper, but not to anyone else', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const someoneElse = await createUser(ctx, { user_type: 'traveler' });
    await completeProfile(ctx, shopper);
    const requestId = await createRequest(ctx, shopper, {
      delivery_same_as_registered: false,
      delivery_address_street: '99 Secret Soi',
      delivery_address_postal_code: '10110',
    });

    const asOwner = await ctx.app.inject({ method: 'GET', url: `/api/requests/${requestId}`, headers: authHeader(shopper) });
    expect(asOwner.json().data.delivery_address_street).toBe('99 Secret Soi');

    const asOther = await ctx.app.inject({
      method: 'GET',
      url: `/api/requests/${requestId}`,
      headers: authHeader(someoneElse),
    });
    expect(asOther.json().data.delivery_address_street).toBeUndefined();
  });

  it('snapshots the shopper\'s current profile address onto the order when same-as-registered, resolved fresh at accept time', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    await completeProfile(ctx, shopper);
    const requestId = await createRequest(ctx, shopper);

    // Move after posting the request but before it's accepted — the order
    // should reflect this new address, not whatever was on file at post time.
    await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(shopper),
      payload: { address_street: '456 New Address Rd', address_city: 'Newtown' },
    });

    const { orderId } = await makeOfferAndAccept(shopper, requestId);
    const order = await ctx.db.selectFrom('orders').selectAll().where('id', '=', orderId).executeTakeFirst();
    expect(order?.delivery_address_street).toBe('456 New Address Rd');
    expect(order?.delivery_address_city).toBe('Newtown');
    expect(order?.delivery_address_country).toBe('US');
  });

  it('snapshots the request\'s own custom delivery address onto the order when same-as-registered is false', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    await completeProfile(ctx, shopper);
    const requestId = await createRequest(ctx, shopper, {
      delivery_same_as_registered: false,
      delivery_address_street: '99 Secret Soi',
      delivery_address_subdistrict: 'Khlong Toei Nuea',
      delivery_address_postal_code: '10110',
      destination_country: 'TH',
      destination_city: 'Bangkok',
    });

    const { orderId } = await makeOfferAndAccept(shopper, requestId);
    const order = await ctx.db.selectFrom('orders').selectAll().where('id', '=', orderId).executeTakeFirst();
    expect(order?.delivery_address_street).toBe('99 Secret Soi');
    expect(order?.delivery_address_subdistrict).toBe('Khlong Toei Nuea');
    expect(order?.delivery_address_postal_code).toBe('10110');
    expect(order?.delivery_address_city).toBe('Bangkok');
    expect(order?.delivery_address_country).toBe('TH');
    // Not the shopper's registered (US) profile address.
    expect(order?.delivery_address_street).not.toBe('1 Market St');
  });
});
