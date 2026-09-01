import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';

describe('operator console', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('serves the console page at / and /admin without auth', async () => {
    for (const url of ['/', '/admin']) {
      const res = await ctx.app.inject({ method: 'GET', url });
      expect(res.statusCode).toBe(200);
      expect(res.headers['content-type']).toContain('text/html');
      expect(res.body).toContain('Hiww');
    }
  });

  it('GET /api/admin/users lists users for an admin and is blocked otherwise', async () => {
    const admin = await createUser(ctx, { admin: true });
    await createUser(ctx, { user_type: 'shopper' });

    const ok = await ctx.app.inject({ method: 'GET', url: '/api/admin/users', headers: authHeader(admin) });
    expect(ok.statusCode).toBe(200);
    expect(Array.isArray(ok.json().data.users)).toBe(true);
    expect(ok.json().data.users.length).toBeGreaterThanOrEqual(2);

    const nobody = await ctx.app.inject({ method: 'GET', url: '/api/admin/users' });
    expect(nobody.statusCode).toBe(401);

    const plain = await createUser(ctx, { user_type: 'both' });
    const forbidden = await ctx.app.inject({ method: 'GET', url: '/api/admin/users', headers: authHeader(plain) });
    expect(forbidden.statusCode).toBe(403);
  });
});
