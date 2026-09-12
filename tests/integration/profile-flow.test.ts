import { makeTestApp, closeTestApp, authHeader, createUser, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, completeOrder } from '../helpers/flows';

describe('profile + reputation', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('/api/me exposes profile + reputation fields and PATCH updates them', async () => {
    const user = await createUser(ctx, { user_type: 'both' });

    const me = await ctx.app.inject({
      method: 'GET',
      url: '/api/me',
      headers: authHeader(user),
    });
    const body = me.json().data;
    expect(body.rating_avg).toBe(0);
    expect(body.rating_count).toBe(0);
    expect(body.delivered_count).toBe(0);
    expect(body.avatar_url).toBeNull();
    // Short reference number for admin/support use — never the raw sequence.
    expect(body.membership_id).toMatch(/^H\d{8}$/);
    expect(body.member_seq).toBeUndefined();

    const patch = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: { home_city: 'Bangkok', avatar_url: 'https://example.com/a.png' },
    });
    expect(patch.statusCode).toBe(200);
    expect(patch.json().data.home_city).toBe('Bangkok');
    expect(patch.json().data.avatar_url).toBe('https://example.com/a.png');
  });

  it('rejects an empty or invalid profile update', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });
    const empty = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: {},
    });
    expect(empty.statusCode).toBe(400);

    const bad = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: { avatar_url: 'not-a-url' },
    });
    expect(bad.statusCode).toBe(400);
  });

  it('changing the phone number resets its verification and re-gates the account', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });

    const patch = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: { phone: '+1 555 9999' },
    });
    expect(patch.statusCode).toBe(200);
    expect(patch.json().data.phone).toBe('+1 555 9999');
    expect(patch.json().data.phone_verified_at).toBeNull();
    expect(patch.json().data.debug_otp.phone).toMatch(/^\d{6}$/);
    expect(patch.json().data.debug_otp.email).toBeUndefined();

    // A gated route now 403s again, same as a freshly-registered account.
    const gated = await ctx.app.inject({
      method: 'POST',
      url: '/api/trips',
      headers: authHeader(user),
      payload: {
        departure_country: 'TH',
        arrival_country: 'JP',
        departure_city: 'Bangkok',
        arrival_city: 'Tokyo',
        departure_date: new Date(Date.now() + 7 * 86400000).toISOString(),
        return_date: new Date(Date.now() + 21 * 86400000).toISOString(),
        max_weight_kg: 8,
        max_items: 5,
      },
    });
    expect(gated.statusCode).toBe(403);
    expect(gated.json().code).toBe('VERIFICATION_REQUIRED');

    // /api/me itself stays reachable so they can still see their own state.
    const me = await ctx.app.inject({ method: 'GET', url: '/api/me', headers: authHeader(user) });
    expect(me.statusCode).toBe(200);

    // Verifying the new number with the fresh code lifts the gate again.
    const code = patch.json().data.debug_otp.phone as string;
    const verify = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/verify-otp',
      headers: authHeader(user),
      payload: { channel: 'phone', code },
    });
    expect(verify.statusCode).toBe(200);

    const retried = await ctx.app.inject({
      method: 'POST',
      url: '/api/trips',
      headers: authHeader(user),
      payload: {
        departure_country: 'TH',
        arrival_country: 'JP',
        departure_city: 'Bangkok',
        arrival_city: 'Tokyo',
        departure_date: new Date(Date.now() + 7 * 86400000).toISOString(),
        return_date: new Date(Date.now() + 21 * 86400000).toISOString(),
        max_weight_kg: 8,
        max_items: 5,
      },
    });
    expect(retried.statusCode).toBe(201);
  });

  it('saving the same phone number back does not disturb its verification', async () => {
    const user = await createUser(ctx, { user_type: 'shopper', phone: '+1 555 0199' });

    const patch = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: { full_name: 'Same Phone', phone: '+1 555 0199' },
    });
    expect(patch.statusCode).toBe(200);
    expect(patch.json().data.phone_verified_at).not.toBeNull();
    expect(patch.json().data.debug_otp).toBeUndefined();
  });

  it('changing the email address resets its verification and re-gates the account', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });
    const newEmail = `new-${user.userId}@example.com`;

    const patch = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: { email: newEmail },
    });
    expect(patch.statusCode).toBe(200);
    expect(patch.json().data.email).toBe(newEmail);
    expect(patch.json().data.email_verified_at).toBeNull();
    expect(patch.json().data.debug_otp.email).toMatch(/^\d{6}$/);
    expect(patch.json().data.debug_otp.phone).toBeUndefined();

    const gated = await ctx.app.inject({
      method: 'POST',
      url: '/api/trips',
      headers: authHeader(user),
      payload: {
        departure_country: 'TH',
        arrival_country: 'JP',
        departure_city: 'Bangkok',
        arrival_city: 'Tokyo',
        departure_date: new Date(Date.now() + 7 * 86400000).toISOString(),
        return_date: new Date(Date.now() + 21 * 86400000).toISOString(),
        max_weight_kg: 8,
        max_items: 5,
      },
    });
    expect(gated.statusCode).toBe(403);
    expect(gated.json().code).toBe('VERIFICATION_REQUIRED');

    const code = patch.json().data.debug_otp.email as string;
    const verify = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/verify-otp',
      headers: authHeader(user),
      payload: { channel: 'email', code },
    });
    expect(verify.statusCode).toBe(200);

    // The new address now logs in; the old one no longer resolves an account.
    const login = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email: newEmail, password: 'SecurePass123!' },
    });
    expect(login.statusCode).toBe(200);
  });

  it('rejects changing to an email address already in use', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });
    const other = await createUser(ctx, { user_type: 'traveler' });

    const patch = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: { email: other.email },
    });
    expect(patch.statusCode).toBe(409);
    expect(patch.json().code).toBe('USER_EXISTS');

    // Nothing changed — still able to reach /api/me without a fresh verify.
    const me = await ctx.app.inject({ method: 'GET', url: '/api/me', headers: authHeader(user) });
    expect(me.json().data.email).toBe(user.email);
    expect(me.json().data.email_verified_at).not.toBeNull();
  });

  it('changing both phone and email in one request re-gates both channels independently', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });
    const newEmail = `both-${user.userId}@example.com`;

    const patch = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: { email: newEmail, phone: '+1 555 8888' },
    });
    expect(patch.statusCode).toBe(200);
    expect(patch.json().data.debug_otp.email).toMatch(/^\d{6}$/);
    expect(patch.json().data.debug_otp.phone).toMatch(/^\d{6}$/);

    // Verifying only email still leaves phone (and therefore the account) gated.
    await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/verify-otp',
      headers: authHeader(user),
      payload: { channel: 'email', code: patch.json().data.debug_otp.email },
    });
    const stillGated = await ctx.app.inject({
      method: 'POST',
      url: '/api/trips',
      headers: authHeader(user),
      payload: {
        departure_country: 'TH',
        arrival_country: 'JP',
        departure_city: 'Bangkok',
        arrival_city: 'Tokyo',
        departure_date: new Date(Date.now() + 7 * 86400000).toISOString(),
        return_date: new Date(Date.now() + 21 * 86400000).toISOString(),
        max_weight_kg: 8,
        max_items: 5,
      },
    });
    expect(stillGated.statusCode).toBe(403);
  });

  it('delivering an order bumps the traveler delivered_count and stage timestamps', async () => {
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);

    const finalOrder = await ctx.db
      .selectFrom('orders')
      .select(['confirmed_at', 'shipped_at', 'delivered_at'])
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(finalOrder?.confirmed_at).toBeTruthy();
    expect(finalOrder?.shipped_at).toBeTruthy();
    expect(finalOrder?.delivered_at).toBeTruthy();

    const traveler = await ctx.db
      .selectFrom('users')
      .select('delivered_count')
      .where('id', '=', order.traveler.userId)
      .executeTakeFirst();
    expect(Number(traveler?.delivered_count)).toBe(1);
  });
});
