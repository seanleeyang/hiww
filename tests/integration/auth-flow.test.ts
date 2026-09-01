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

  it('registers a user and allows a bearer token to create a trip', async () => {
    const email = `alice-auth-${randomUUID()}@example.com`;
    const registerResponse = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email,
        full_name: 'Alice Traveler',
        user_type: 'traveler',
        password: 'SecurePass123!',
      },
    });

    expect(registerResponse.statusCode).toBe(201);
    const registerBody = registerResponse.json();
    expect(registerBody.success).toBe(true);
    expect(registerBody.data.token).toBeTruthy();

    const token = registerBody.data.token as string;

    const tripResponse = await ctx.app.inject({
      method: 'POST',
      url: '/api/trips',
      headers: { authorization: `Bearer ${token}` },
      payload: {
        departure_country: 'US',
        arrival_country: 'FR',
        departure_date: '2026-10-15T08:00:00.000Z',
        return_date: '2026-10-22T08:00:00.000Z',
        max_weight_kg: 25,
        max_items: 3,
      },
    });

    expect(tripResponse.statusCode).toBe(201);

    const user = await ctx.db
      .selectFrom('users')
      .selectAll()
      .where('email', '=', email)
      .executeTakeFirst();

    expect(user?.full_name).toBe('Alice Traveler');
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
