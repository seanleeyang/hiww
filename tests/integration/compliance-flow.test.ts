import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';

describe('compliance / KYC flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('a user submits KYC and an admin approves it', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });
    const admin = await createUser(ctx, { admin: true });

    const submit = await ctx.app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/submit',
      headers: authHeader(user),
      payload: { document_type: 'passport', document_id: 'ABC12345' },
    });
    expect(submit.statusCode).toBe(201);

    const approve = await ctx.app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/approve',
      headers: authHeader(admin),
      payload: { user_id: user.userId, status: 'approved' },
    });

    expect(approve.statusCode).toBe(200);
    expect(approve.json().success).toBe(true);

    const updated = await ctx.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', user.userId)
      .executeTakeFirst();
    expect(updated?.kyc_status).toBe('approved');
  });

  it('a non-admin cannot approve KYC (no self-approval)', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });

    const approve = await ctx.app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/approve',
      headers: authHeader(user),
      payload: { user_id: user.userId, status: 'approved' },
    });

    expect(approve.statusCode).toBe(403);
  });
});
