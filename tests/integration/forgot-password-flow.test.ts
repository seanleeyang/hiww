import { randomUUID } from 'crypto';
import { makeTestApp, closeTestApp, type TestContext } from '../helpers/test-app';

describe('Forgot password', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  async function register(email = `forgot-${randomUUID()}@example.com`) {
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email,
        full_name: 'Forgetful Tester',
        user_type: 'shopper',
        phone: '+1 555 0100',
        password: 'OriginalPass123!',
      },
    });
    return { email, res };
  }

  it('does not require auth to request or complete a reset', async () => {
    const { email } = await register();

    const forgot = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/forgot-password',
      payload: { email },
    });
    expect(forgot.statusCode).toBe(200);
    const code = forgot.json().data.debug_otp as string;
    expect(code).toMatch(/^\d{6}$/);

    const reset = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/reset-password',
      payload: { email, code, new_password: 'BrandNewPass456!' },
    });
    expect(reset.statusCode).toBe(200);
    expect(reset.json().data.token).toBeTruthy();
  });

  it('lets the new password log in and rejects the old one', async () => {
    const { email } = await register();

    const forgot = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/forgot-password',
      payload: { email },
    });
    const code = forgot.json().data.debug_otp as string;

    await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/reset-password',
      payload: { email, code, new_password: 'BrandNewPass456!' },
    });

    const oldLogin = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email, password: 'OriginalPass123!' },
    });
    expect(oldLogin.statusCode).toBe(401);

    const newLogin = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email, password: 'BrandNewPass456!' },
    });
    expect(newLogin.statusCode).toBe(200);
  });

  it('invalidates whatever session was active before the reset — the actual point of a reset if the account was compromised', async () => {
    const { email, res } = await register();
    const tokenBeforeReset = res.json().data.token as string;

    const forgot = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/forgot-password',
      payload: { email },
    });
    const code = forgot.json().data.debug_otp as string;

    await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/reset-password',
      payload: { email, code, new_password: 'BrandNewPass456!' },
    });

    const stillSignedIn = await ctx.app.inject({
      method: 'GET',
      url: '/api/me',
      headers: { authorization: `Bearer ${tokenBeforeReset}` },
    });
    expect(stillSignedIn.statusCode).toBe(401);
  });

  it('does not reveal whether an email is registered', async () => {
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/forgot-password',
      payload: { email: `nobody-${randomUUID()}@example.com` },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().data.sent).toBe(true);
    expect(res.json().data.debug_otp).toBeUndefined();
  });

  it('rejects a wrong or already-consumed code', async () => {
    const { email } = await register();

    const forgot = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/forgot-password',
      payload: { email },
    });
    const code = forgot.json().data.debug_otp as string;

    const wrong = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/reset-password',
      payload: { email, code: '000000', new_password: 'BrandNewPass456!' },
    });
    expect(wrong.statusCode).toBe(400);
    expect(wrong.json().code).toBe('INVALID_OTP');

    const ok = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/reset-password',
      payload: { email, code, new_password: 'BrandNewPass456!' },
    });
    expect(ok.statusCode).toBe(200);

    const replay = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/reset-password',
      payload: { email, code, new_password: 'YetAnotherPass789!' },
    });
    expect(replay.statusCode).toBe(400);
  });

  it('rejects reset-password for an email that was never registered', async () => {
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/reset-password',
      payload: { email: `nobody-${randomUUID()}@example.com`, code: '123456', new_password: 'BrandNewPass456!' },
    });
    expect(res.statusCode).toBe(400);
    expect(res.json().code).toBe('INVALID_OTP');
  });
});
