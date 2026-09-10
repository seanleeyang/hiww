import { randomUUID } from 'crypto';
import { makeTestApp, closeTestApp, type TestContext } from '../helpers/test-app';
import { signToken } from '@/utils/auth';

describe('OTP verification at registration', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  async function register(phone = '+1 555 0100') {
    const email = `otp-${randomUUID()}@example.com`;
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: { email, full_name: 'Otp Tester', user_type: 'shopper', phone, password: 'SecurePass123!' },
    });
    return { email, res };
  }

  it('rejects registration with no phone number', async () => {
    const email = `otp-${randomUUID()}@example.com`;
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: { email, full_name: 'No Phone', user_type: 'shopper', password: 'SecurePass123!' },
    });
    expect(res.statusCode).toBe(400);
  });

  it('lets an unverified user reach GET /api/me but blocks everything else', async () => {
    const { res } = await register();
    const token = res.json().data.token as string;
    const headers = { authorization: `Bearer ${token}` };

    const me = await ctx.app.inject({ method: 'GET', url: '/api/me', headers });
    expect(me.statusCode).toBe(200);
    expect(me.json().data.email_verified_at).toBeNull();
    expect(me.json().data.phone_verified_at).toBeNull();

    const trips = await ctx.app.inject({ method: 'GET', url: '/api/trips', headers });
    expect(trips.statusCode).toBe(403);
    expect(trips.json().code).toBe('VERIFICATION_REQUIRED');

    // The exemption is GET-only — editing the profile still requires full
    // verification, even though *viewing* it doesn't.
    const patch = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers,
      payload: { full_name: 'New Name' },
    });
    expect(patch.statusCode).toBe(403);
    expect(patch.json().code).toBe('VERIFICATION_REQUIRED');
  });

  it('rejects a wrong or already-consumed code', async () => {
    const { res } = await register();
    const { token, debug_otp: otp } = res.json().data as { token: string; debug_otp: { email: string } };
    const headers = { authorization: `Bearer ${token}` };

    const wrong = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/verify-otp',
      headers,
      payload: { channel: 'email', code: '000000' },
    });
    expect(wrong.statusCode).toBe(400);
    expect(wrong.json().code).toBe('INVALID_OTP');

    const ok = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/verify-otp',
      headers,
      payload: { channel: 'email', code: otp.email },
    });
    expect(ok.statusCode).toBe(200);

    // Same code again: already consumed.
    const replay = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/verify-otp',
      headers,
      payload: { channel: 'email', code: otp.email },
    });
    expect(replay.statusCode).toBe(400);
  });

  it('rejects an expired code', async () => {
    const { res } = await register();
    const { userId, token, debug_otp: otp } = res.json().data as {
      userId: string;
      token: string;
      debug_otp: { email: string };
    };
    const headers = { authorization: `Bearer ${token}` };

    await ctx.db
      .updateTable('otp_codes')
      .set({ expires_at: new Date(Date.now() - 60_000) })
      .where('user_id', '=', userId)
      .where('channel', '=', 'email')
      .execute();

    const expired = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/verify-otp',
      headers,
      payload: { channel: 'email', code: otp.email },
    });
    expect(expired.statusCode).toBe(400);
  });

  it('resend invalidates the old code and issues a new one', async () => {
    const { res } = await register();
    const { token, debug_otp: original } = res.json().data as { token: string; debug_otp: { email: string } };
    const headers = { authorization: `Bearer ${token}` };

    const resend = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/resend-otp',
      headers,
      payload: { channel: 'email' },
    });
    expect(resend.statusCode).toBe(200);
    const fresh = resend.json().data.debug_otp as string;
    expect(fresh).not.toBe(original.email);

    const oldOneFails = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/verify-otp',
      headers,
      payload: { channel: 'email', code: original.email },
    });
    expect(oldOneFails.statusCode).toBe(400);

    const newOneWorks = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/verify-otp',
      headers,
      payload: { channel: 'email', code: fresh },
    });
    expect(newOneWorks.statusCode).toBe(200);
  });

  it('an already-verified pre-existing account is not affected (grandfathered)', async () => {
    // Simulates a user who existed before this feature shipped: migration
    // 020 backfills their verified_at columns, so they should never see the
    // verification gate.
    const email = `legacy-${randomUUID()}@example.com`;
    const id = randomUUID();
    const now = new Date();
    await ctx.db
      .insertInto('users')
      .values({
        id,
        email,
        full_name: 'Legacy User',
        user_type: 'shopper',
        kyc_status: 'pending',
        password_hash: 'scrypt$00$00',
        email_verified_at: now,
        phone_verified_at: now,
        created_at: now,
        updated_at: now,
      })
      .execute();

    const token = signToken({ userId: id, email, exp: Date.now() + 60_000 });
    const trips = await ctx.app.inject({
      method: 'GET',
      url: '/api/trips',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(trips.statusCode).toBe(200);
  });
});
