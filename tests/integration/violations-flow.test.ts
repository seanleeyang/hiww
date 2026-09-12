import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';

describe('3-strikes violations system', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  const logViolation = (admin: Awaited<ReturnType<typeof createUser>>, userId: string, reason: string) =>
    ctx.app.inject({
      method: 'POST',
      url: `/api/admin/users/${userId}/violations`,
      headers: authHeader(admin),
      payload: { reason },
    });

  it('1st strike: warns and flags, but does not sign the user out or block login', async () => {
    const admin = await createUser(ctx, { admin: true });
    const user = await createUser(ctx);

    const res = await logViolation(admin, user.userId, 'Posted a listing for a prohibited item');
    expect(res.statusCode).toBe(201);
    expect(res.json().data).toMatchObject({ count: 1, risk_status: 'flagged', suspended_until: null });

    // Still signed in — a warning doesn't kick anyone out.
    const me = await ctx.app.inject({ method: 'GET', url: '/api/me', headers: authHeader(user) });
    expect(me.statusCode).toBe(200);

    const notifs = await ctx.app.inject({ method: 'GET', url: '/api/notifications', headers: authHeader(user) });
    const items = notifs.json().data.items as Array<{ type: string; body: string }>;
    const warning = items.find((n) => n.type === 'account_warned');
    expect(warning).toBeDefined();
    expect(warning?.body).toContain('Posted a listing for a prohibited item');
  });

  it('2nd strike: suspends for 7 days, signs the user out immediately, and blocks login until then', async () => {
    const admin = await createUser(ctx, { admin: true });
    const user = await createUser(ctx);
    await logViolation(admin, user.userId, 'First warning');

    const second = await logViolation(admin, user.userId, 'Sent a harassing message');
    expect(second.statusCode).toBe(201);
    expect(second.json().data.count).toBe(2);
    expect(second.json().data.risk_status).toBe('restricted');
    expect(second.json().data.suspended_until).toBeTruthy();

    // Signed out immediately — the token from before the strike is dead.
    const me = await ctx.app.inject({ method: 'GET', url: '/api/me', headers: authHeader(user) });
    expect(me.statusCode).toBe(401);

    // Can't log back in either, with a clear reason why.
    const login = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email: user.email, password: 'SecurePass123!' },
    });
    expect(login.statusCode).toBe(403);
    expect(login.json().code).toBe('ACCOUNT_RESTRICTED');
    expect(login.json().error).toMatch(/suspended until \d{4}-\d{2}-\d{2}/);

    const notifs = await ctx.app.inject({ method: 'GET', url: '/api/notifications', headers: authHeader(admin) });
    // Admin's own feed is unrelated; just confirming the endpoint didn't 500 —
    // the suspended user's own notification is checked via direct DB below
    // since they can no longer authenticate to fetch their own feed.
    expect(notifs.statusCode).toBe(200);

    const stored = await ctx.db
      .selectFrom('notifications')
      .select(['type', 'body'])
      .where('user_id', '=', user.userId)
      .where('type', '=', 'account_suspended')
      .executeTakeFirst();
    expect(stored?.body).toContain('Sent a harassing message');
  });

  it('3rd strike: permanent ban, no suspended_until, login blocked indefinitely', async () => {
    const admin = await createUser(ctx, { admin: true });
    const user = await createUser(ctx);
    await logViolation(admin, user.userId, 'Strike one');
    await logViolation(admin, user.userId, 'Strike two');

    const third = await logViolation(admin, user.userId, 'Attempted to scam a shopper');
    expect(third.statusCode).toBe(201);
    expect(third.json().data).toMatchObject({ count: 3, risk_status: 'restricted', suspended_until: null });

    const login = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email: user.email, password: 'SecurePass123!' },
    });
    expect(login.statusCode).toBe(403);
    expect(login.json().code).toBe('ACCOUNT_RESTRICTED');
    expect(login.json().error).toBe('Your account has been permanently banned.');
  });

  it('a suspension that has already passed no longer blocks login', async () => {
    const admin = await createUser(ctx, { admin: true });
    const user = await createUser(ctx);
    await logViolation(admin, user.userId, 'Strike one');
    await logViolation(admin, user.userId, 'Strike two');

    // Fast-forward past the 7-day suspension.
    await ctx.db
      .updateTable('users')
      .set({ suspended_until: new Date(Date.now() - 1000) })
      .where('id', '=', user.userId)
      .execute();

    const login = await ctx.app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email: user.email, password: 'SecurePass123!' },
    });
    expect(login.statusCode).toBe(200);
  });

  it('lists a user\'s full violation history, most recent first', async () => {
    const admin = await createUser(ctx, { admin: true });
    const user = await createUser(ctx);
    await logViolation(admin, user.userId, 'First one');
    await logViolation(admin, user.userId, 'Second one');

    const history = await ctx.app.inject({
      method: 'GET',
      url: `/api/admin/users/${user.userId}/violations`,
      headers: authHeader(admin),
    });
    expect(history.statusCode).toBe(200);
    const items = history.json().data.items as Array<{ reason: string; issued_by_name: string }>;
    expect(items).toHaveLength(2);
    expect(items[0].reason).toBe('Second one');
    expect(items[1].reason).toBe('First one');
    expect(items[0].issued_by_name).toBe('Test User');
  });

  it('rejects logging a violation for a non-admin', async () => {
    const attacker = await createUser(ctx);
    const victim = await createUser(ctx);

    const res = await logViolation(attacker, victim.userId, 'Trying to strike someone as a non-admin');
    expect(res.statusCode).toBe(403);
  });

  it('rejects a violation with no reason', async () => {
    const admin = await createUser(ctx, { admin: true });
    const user = await createUser(ctx);

    const res = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/users/${user.userId}/violations`,
      headers: authHeader(admin),
      payload: {},
    });
    expect(res.statusCode).toBe(400);
  });

  it('404s for a nonexistent user', async () => {
    const admin = await createUser(ctx, { admin: true });
    const res = await logViolation(admin, '00000000-0000-0000-0000-000000000000', 'Ghost user');
    expect(res.statusCode).toBe(404);
  });
});
