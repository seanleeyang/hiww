import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';

describe('POST /api/auth/change-password', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('changes the password when the current password is correct', async () => {
    const user = await createUser(ctx); // password is 'SecurePass123!'

    const change = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/change-password',
      headers: authHeader(user),
      payload: { current_password: 'SecurePass123!', new_password: 'BrandNewPass456!' },
    });
    expect(change.statusCode).toBe(200);
    expect(change.json().success).toBe(true);

    // Old password no longer works.
    const oldLogin = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email: user.email, password: 'SecurePass123!' },
    });
    expect(oldLogin.statusCode).toBe(401);

    // New password works.
    const newLogin = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email: user.email, password: 'BrandNewPass456!' },
    });
    expect(newLogin.statusCode).toBe(200);
  });

  it('invalidates the old token everywhere, but hands back a fresh one this device keeps using', async () => {
    const user = await createUser(ctx); // password is 'SecurePass123!'

    const change = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/change-password',
      headers: authHeader(user),
      payload: { current_password: 'SecurePass123!', new_password: 'BrandNewPass456!' },
    });
    expect(change.statusCode).toBe(200);
    const freshToken = change.json().data.token as string;
    expect(freshToken).toBeTruthy();

    // The token used to make this very request is now dead — a stolen
    // device or an old forgotten-about session with this same token stops
    // working the instant the password changes.
    const withOldToken = await ctx.app.inject({
      method: 'GET',
      url: '/api/me',
      headers: authHeader(user),
    });
    expect(withOldToken.statusCode).toBe(401);

    // The fresh token handed back in the response still works — this
    // device's own session isn't kicked out by its own password change.
    const withFreshToken = await ctx.app.inject({
      method: 'GET',
      url: '/api/me',
      headers: { authorization: `Bearer ${freshToken}` },
    });
    expect(withFreshToken.statusCode).toBe(200);
  });

  it('rejects a wrong current password without changing anything', async () => {
    const user = await createUser(ctx);

    const change = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/change-password',
      headers: authHeader(user),
      payload: { current_password: 'TotallyWrong123', new_password: 'BrandNewPass456!' },
    });
    expect(change.statusCode).toBe(401);

    const login = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email: user.email, password: 'SecurePass123!' },
    });
    expect(login.statusCode).toBe(200);
  });

  it('rejects a new password that fails the strength policy', async () => {
    const user = await createUser(ctx);

    const change = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/change-password',
      headers: authHeader(user),
      payload: { current_password: 'SecurePass123!', new_password: 'nodigits' },
    });
    expect(change.statusCode).toBe(400);

    // Original password still works — the weak one was never applied.
    const login = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email: user.email, password: 'SecurePass123!' },
    });
    expect(login.statusCode).toBe(200);
  });

  it('requires authentication', async () => {
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/change-password',
      payload: { current_password: 'whatever', new_password: 'BrandNewPass456!' },
    });
    expect(res.statusCode).toBe(401);
  });
});
