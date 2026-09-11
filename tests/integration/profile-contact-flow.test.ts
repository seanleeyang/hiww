import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createRequest, createTrip } from '../helpers/flows';

describe('profile contact details + completeness gate', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('lets a user set phone and address via PATCH /api/me, and returns them from GET /api/me', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });

    const patch = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: {
        phone: '+1 555 0100',
        address_street: '1 Market St',
        address_city: 'Springfield',
        address_postal_code: '12345',
        address_country: 'US',
      },
    });
    expect(patch.statusCode).toBe(200);
    expect(patch.json().data.phone).toBe('+1 555 0100');
    expect(patch.json().data.address_city).toBe('Springfield');

    const me = await ctx.app.inject({ method: 'GET', url: '/api/me', headers: authHeader(user) });
    expect(me.json().data.address_country).toBe('US');
  });

  it('rejects an invalid phone number', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });
    const res = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: { phone: 'not-a-phone!!' },
    });
    expect(res.statusCode).toBe(400);
  });

  it('blocks a traveler from making an offer until their phone + address are filled in', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const requestId = await createRequest(ctx, shopper);
    const tripId = await createTrip(ctx, traveler);

    const blocked = await ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(traveler),
      payload: {
        request_id: requestId,
        trip_id: tripId,
        quoted_price: '120.00',
        delivery_date: '2026-11-18T10:00:00.000Z',
      },
    });
    expect(blocked.statusCode).toBe(403);
    expect(blocked.json().code).toBe('PROFILE_INCOMPLETE');

    await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(traveler),
      payload: {
        phone: '+1 555 0100',
        address_street: '1 Market St',
        address_city: 'Springfield',
        address_postal_code: '12345',
        address_country: 'US',
      },
    });

    const ok = await ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(traveler),
      payload: {
        request_id: requestId,
        trip_id: tripId,
        quoted_price: '120.00',
        delivery_date: '2026-11-18T10:00:00.000Z',
      },
    });
    expect(ok.statusCode).toBe(201);
  });

  it('blocks a shopper from accepting an offer until their phone + address are filled in', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(traveler),
      payload: {
        phone: '+1 555 0100',
        address_street: '1 Market St',
        address_city: 'Springfield',
        address_postal_code: '12345',
        address_country: 'US',
      },
    });
    const requestId = await createRequest(ctx, shopper);
    const tripId = await createTrip(ctx, traveler);

    const offerRes = await ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(traveler),
      payload: {
        request_id: requestId,
        trip_id: tripId,
        quoted_price: '120.00',
        delivery_date: '2026-11-18T10:00:00.000Z',
      },
    });
    const offerId = offerRes.json().data.id as string;

    const blocked = await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/accept`,
      headers: authHeader(shopper),
      payload: {},
    });
    expect(blocked.statusCode).toBe(403);
    expect(blocked.json().code).toBe('PROFILE_INCOMPLETE');

    // Same phone number the shopper already registered with (createUser's
    // default) — this test is about the address fields being missing, not
    // about a phone *change*, which now re-triggers verification (see
    // profile-flow.test.ts) and would 403 this accept-offer call below.
    await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(shopper),
      payload: {
        phone: '+1 555 0100',
        address_street: '2 Elm St',
        address_city: 'Shelbyville',
        address_postal_code: '54321',
        address_country: 'US',
      },
    });

    const ok = await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/accept`,
      headers: authHeader(shopper),
      payload: {},
    });
    expect(ok.statusCode).toBe(200);
  });

  it('never exposes phone/address on another user\'s public summary', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(shopper),
      payload: { phone: '+1 555 0100', address_city: 'Springfield' },
    });
    const requestId = await createRequest(ctx, shopper);
    const viewer = await createUser(ctx, { user_type: 'traveler' });

    const res = await ctx.app.inject({
      method: 'GET',
      url: `/api/requests/${requestId}`,
      headers: authHeader(viewer),
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().data.shopper.phone).toBeUndefined();
    expect(res.json().data.shopper.address_street).toBeUndefined();
    expect(res.json().data.shopper.address_city).toBeUndefined();
  });
});
