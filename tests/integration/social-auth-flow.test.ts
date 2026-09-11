import { makeTestApp, closeTestApp, createUser, type TestContext } from '../helpers/test-app';
import { __setSocialTokenVerifier } from '@/modules/auth/routes';

describe('POST /api/auth/social', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    __setSocialTokenVerifier(undefined);
    await closeTestApp(ctx);
  });

  it('is reachable without an Authorization header (it IS the login)', async () => {
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/social',
      payload: { provider: 'google', token: 'whatever' },
    });
    // Not 401 — the auth guard must not gate this route, whatever it decides
    // about the token itself.
    expect(res.statusCode).not.toBe(401);
  });

  it('rejects a malformed payload', async () => {
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/social',
      payload: { provider: 'not-a-real-provider', token: '' },
    });
    expect(res.statusCode).toBe(400);
    expect(res.json().code).toBe('VALIDATION_ERROR');
  });

  it('501s a provider with no configured credentials, rather than crashing', async () => {
    // GOOGLE_CLIENT_ID/LINE_CHANNEL_ID/FACEBOOK_APP_ID are all unset in the
    // test environment by default, and apple has no verification implemented
    // at all yet.
    for (const provider of ['google', 'apple', 'facebook', 'line']) {
      const res = await ctx.app.inject({
        method: 'POST',
        url: '/api/auth/social',
        payload: { provider, token: 'whatever' },
      });
      expect(res.statusCode).toBe(501);
      expect(res.json().code).toBe('NOT_IMPLEMENTED');
    }
  });

  it('reclaims a squatted (never-verified) account instead of trusting its password', async () => {
    const email = `squatted-${Date.now()}@example.com`;
    const squat = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email,
        full_name: 'Squatter',
        user_type: 'both',
        phone: '+1 555 0100',
        password: 'SquatterPassword1',
      },
    });
    expect(squat.statusCode).toBe(201);
    const squattedUserId = squat.json().data.userId as string;

    // Never completes OTP — email_verified_at stays null, same as the real
    // exploit: register-and-abandon on someone else's email address.
    __setSocialTokenVerifier(async () => ({
      providerId: 'google-sub-123',
      email,
      emailVerified: true,
      fullName: 'Real Owner',
    }));

    const social = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/social',
      payload: { provider: 'google', token: 'whatever' },
    });
    expect(social.statusCode).toBe(200);
    // Same row is reclaimed, not a second account created (email is unique).
    expect(social.json().data.userId).toBe(squattedUserId);

    // The squatter's original password no longer works.
    const login = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email, password: 'SquatterPassword1' },
    });
    expect(login.statusCode).toBe(401);

    const row = await ctx.db
      .selectFrom('users')
      .select(['password_hash', 'email_verified_at'])
      .where('id', '=', squattedUserId)
      .executeTakeFirst();
    expect(row?.password_hash).toBeNull();
    expect(row?.email_verified_at).not.toBeNull();
  });

  it('does not touch the password when linking to an already-verified account', async () => {
    const user = await createUser(ctx); // createUser verifies email+phone already

    __setSocialTokenVerifier(async () => ({
      providerId: 'google-sub-456',
      email: user.email,
      emailVerified: true,
      fullName: 'Test User',
    }));

    const social = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/social',
      payload: { provider: 'google', token: 'whatever' },
    });
    expect(social.statusCode).toBe(200);
    expect(social.json().data.userId).toBe(user.userId);

    // Still able to log in with the original password — nothing was reclaimed.
    const login = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email: user.email, password: 'SecurePass123!' },
    });
    expect(login.statusCode).toBe(200);
  });
});
