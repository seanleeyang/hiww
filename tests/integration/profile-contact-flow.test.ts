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

  it('lets a user set gender, date of birth, and the extended Thai address fields', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });

    const patch = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: {
        gender: 'female',
        date_of_birth: '1990-05-20',
        address_street: '99/1 Sukhumvit Rd',
        address_street2: 'Floor 4',
        address_subdistrict: 'Khlong Toei Nuea',
        address_district: 'Watthana',
        address_city: 'Bangkok',
        address_postal_code: '10110',
        address_country: 'TH',
      },
    });
    expect(patch.statusCode).toBe(200);
    expect(patch.json().data.gender).toBe('female');
    expect(patch.json().data.address_subdistrict).toBe('Khlong Toei Nuea');
    expect(patch.json().data.address_district).toBe('Watthana');

    const me = await ctx.app.inject({ method: 'GET', url: '/api/me', headers: authHeader(user) });
    expect(me.json().data.address_street2).toBe('Floor 4');
    expect(me.json().data.date_of_birth).toBe('1990-05-20');
  });

  it('lets a user set and clear their bank account details via PATCH /api/me', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });

    const patch = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: { bank_name: 'Kasikornbank (KBank)', bank_account_number: '1234567890' },
    });
    expect(patch.statusCode).toBe(200);
    expect(patch.json().data.bank_name).toBe('Kasikornbank (KBank)');
    expect(patch.json().data.bank_account_number).toBe('1234567890');

    const me = await ctx.app.inject({ method: 'GET', url: '/api/me', headers: authHeader(user) });
    expect(me.json().data.bank_name).toBe('Kasikornbank (KBank)');

    const cleared = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: { bank_name: null, bank_account_number: null },
    });
    expect(cleared.statusCode).toBe(200);
    expect(cleared.json().data.bank_name).toBeNull();
  });

  it('rejects a date of birth under 18 years old', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });
    const underage = new Date();
    underage.setUTCFullYear(underage.getUTCFullYear() - 17);
    const dob = underage.toISOString().slice(0, 10);

    const res = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: { date_of_birth: dob },
    });
    expect(res.statusCode).toBe(400);
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
    // createUser already gives the traveler a phone number — only the
    // address is missing, so that's the only thing the message should name.
    expect(blocked.json().error).toBe('Add your delivery address before your first order');

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

  it('names only phone when just the phone is missing, and both when both are', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const requestId = await createRequest(ctx, shopper);

    // Missing phone only — cleared directly in the DB (not via PATCH
    // /api/me, which would also clear phone_verified_at and trip the
    // separate verification gate before ever reaching this check) with the
    // address filled in.
    const noPhoneTraveler = await createUser(ctx, { user_type: 'traveler' });
    await ctx.db
      .updateTable('users')
      .set({
        phone: null,
        address_street: '1 Market St',
        address_city: 'Springfield',
        address_postal_code: '12345',
        address_country: 'US',
      })
      .where('id', '=', noPhoneTraveler.userId)
      .execute();
    const tripA = await createTrip(ctx, noPhoneTraveler);
    const blockedPhone = await ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(noPhoneTraveler),
      payload: { request_id: requestId, trip_id: tripA, quoted_price: '120.00', delivery_date: '2026-11-18T10:00:00.000Z' },
    });
    expect(blockedPhone.statusCode).toBe(403);
    expect(blockedPhone.json().error).toBe('Add your phone number before your first order');

    // Missing both — a brand new traveler who never touched either field
    // (createUser always sets a default phone, so clear it here too).
    const missingBothTraveler = await createUser(ctx, { user_type: 'traveler' });
    await ctx.db.updateTable('users').set({ phone: null }).where('id', '=', missingBothTraveler.userId).execute();
    const tripB = await createTrip(ctx, missingBothTraveler);
    const blockedBoth = await ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(missingBothTraveler),
      payload: { request_id: requestId, trip_id: tripB, quoted_price: '120.00', delivery_date: '2026-11-18T10:00:00.000Z' },
    });
    expect(blockedBoth.statusCode).toBe(403);
    expect(blockedBoth.json().error).toBe('Add your phone number and delivery address before your first order');
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
    // The shopper already has a phone number (createUser's default) — only
    // the address is missing, so the message should name just that, not
    // claim the phone number is missing too.
    expect(blocked.json().error).toBe('Add your delivery address before your first order');

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
    expect(res.json().data.shopper.bank_name).toBeUndefined();
    expect(res.json().data.shopper.bank_account_number).toBeUndefined();
  });
});
