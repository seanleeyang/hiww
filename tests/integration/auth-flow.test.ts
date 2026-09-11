import { randomUUID } from 'crypto';
import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';

describe('auth and protected route flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('registers a user and allows a bearer token to create a trip once verified', async () => {
    const email = `alice-auth-${randomUUID()}@example.com`;
    const registerResponse = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email,
        full_name: 'Alice Traveler',
        user_type: 'traveler',
        phone: '+1 555 0100',
        password: 'SecurePass123!',
      },
    });

    expect(registerResponse.statusCode).toBe(201);
    const registerBody = registerResponse.json();
    expect(registerBody.success).toBe(true);
    expect(registerBody.data.token).toBeTruthy();
    expect(registerBody.data.debug_otp.email).toMatch(/^\d{6}$/);
    expect(registerBody.data.debug_otp.phone).toMatch(/^\d{6}$/);

    const token = registerBody.data.token as string;
    const headers = { authorization: `Bearer ${token}` };
    const tripPayload = {
      departure_country: 'US',
      arrival_country: 'FR',
      departure_date: '2026-10-15T08:00:00.000Z',
      return_date: '2026-10-22T08:00:00.000Z',
      max_weight_kg: 25,
      max_items: 3,
    };

    const blocked = await ctx.app.inject({ method: 'POST', url: '/api/trips', headers, payload: tripPayload });
    expect(blocked.statusCode).toBe(403);
    expect(blocked.json().code).toBe('VERIFICATION_REQUIRED');

    await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/verify-otp',
      headers,
      payload: { channel: 'email', code: registerBody.data.debug_otp.email },
    });
    // Phone still unverified — still blocked.
    const stillBlocked = await ctx.app.inject({ method: 'POST', url: '/api/trips', headers, payload: tripPayload });
    expect(stillBlocked.statusCode).toBe(403);

    await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/verify-otp',
      headers,
      payload: { channel: 'phone', code: registerBody.data.debug_otp.phone },
    });

    const tripResponse = await ctx.app.inject({ method: 'POST', url: '/api/trips', headers, payload: tripPayload });
    expect(tripResponse.statusCode).toBe(201);

    const user = await ctx.db
      .selectFrom('users')
      .selectAll()
      .where('email', '=', email)
      .executeTakeFirst();

    expect(user?.full_name).toBe('Alice Traveler');
    expect(user?.email_verified_at).toBeTruthy();
    expect(user?.phone_verified_at).toBeTruthy();
  });

  it('rejects a protected route with no token', async () => {
    const response = await ctx.app.inject({
      method: 'POST',
      url: '/api/trips',
      payload: {
        departure_country: 'US',
        arrival_country: 'FR',
        departure_date: '2026-10-15T08:00:00.000Z',
        return_date: '2026-10-22T08:00:00.000Z',
        max_weight_kg: 25,
        max_items: 3,
      },
    });

    expect(response.statusCode).toBe(401);
  });

  it('ignores a spoofed x-user-id header (no impersonation)', async () => {
    const victim = await createUser(ctx, { user_type: 'traveler' });

    const response = await ctx.app.inject({
      method: 'POST',
      url: '/api/trips',
      headers: { 'x-user-id': victim.userId },
      payload: {
        departure_country: 'US',
        arrival_country: 'FR',
        departure_date: '2026-10-15T08:00:00.000Z',
        return_date: '2026-10-22T08:00:00.000Z',
        max_weight_kg: 25,
        max_items: 3,
      },
    });

    expect(response.statusCode).toBe(401);
  });

  it('rejects registration passwords that fail the strength policy', async () => {
    const cases = [
      { password: 'short1', reason: 'under 8 characters' },
      { password: 'alllettersnodigits', reason: 'no digit' },
      { password: '12345678', reason: 'no letter' },
    ];
    for (const { password } of cases) {
      const res = await ctx.app.inject({
        method: 'POST',
        url: '/api/auth/register',
        payload: {
          email: `weak-${randomUUID()}@example.com`,
          full_name: 'Weak Password',
          user_type: 'shopper',
          phone: '+1 555 0100',
          password,
        },
      });
      expect(res.statusCode).toBe(400);
    }
  });

  it('accepts an 8+ character password mixing letters and digits, special characters optional', async () => {
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: `strongenough-${randomUUID()}@example.com`,
        full_name: 'Strong Enough',
        user_type: 'shopper',
        phone: '+1 555 0100',
        password: 'letters123', // no special character — must still pass
      },
    });
    expect(res.statusCode).toBe(201);
  });

  it('rejects a login with the wrong password', async () => {
    const user = await createUser(ctx, { user_type: 'both' });

    const ok = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email: user.email, password: 'SecurePass123!' },
    });
    expect(ok.statusCode).toBe(200);

    const bad = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email: user.email, password: 'wrong-password' },
    });
    expect(bad.statusCode).toBe(401);
  });

  it('lets an authenticated user reach a protected route', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });
    const response = await ctx.app.inject({
      method: 'GET',
      url: '/api/trips',
      headers: authHeader(user),
    });
    expect(response.statusCode).toBe(200);
  });
});
