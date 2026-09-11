import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';

const submitPayload = {
  document_type: 'passport',
  document_id: 'ABC12345',
  document_name: 'Jane A Traveler',
  document_photo_url: 'https://example.com/uploads/id-front.jpg',
};

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
      payload: submitPayload,
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

  it('rejects a submission missing the document photo or name', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });

    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/submit',
      headers: authHeader(user),
      payload: { document_type: 'passport', document_id: 'ABC12345' },
    });
    expect(res.statusCode).toBe(400);
  });

  it('persists the submitted document details and photo(s) for an admin to review', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });
    const admin = await createUser(ctx, { admin: true });

    const submit = await ctx.app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/submit',
      headers: authHeader(user),
      payload: {
        ...submitPayload,
        document_photo_back_url: 'https://example.com/uploads/visa-page.jpg',
      },
    });
    expect(submit.statusCode).toBe(201);

    const row = await ctx.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', user.userId)
      .executeTakeFirst();
    expect(row?.kyc_document_type).toBe('passport');
    expect(row?.kyc_document_id).toBe('ABC12345');
    expect(row?.kyc_document_name).toBe('Jane A Traveler');
    expect(row?.kyc_document_photo_url).toBe('https://example.com/uploads/id-front.jpg');
    expect(row?.kyc_document_photo_back_url).toBe('https://example.com/uploads/visa-page.jpg');
    expect(row?.kyc_submitted_at).not.toBeNull();

    const reviews = await ctx.app.inject({
      method: 'GET',
      url: '/api/admin/reviews',
      headers: authHeader(admin),
    });
    const queue = reviews.json().data.queue as Array<Record<string, unknown>>;
    const entry = queue.find((q) => q.type === 'kyc' && q.user_id === user.userId);
    expect(entry).toBeDefined();
    expect(entry?.document_name).toBe('Jane A Traveler');
    expect(entry?.document_photo_url).toBe('https://example.com/uploads/id-front.jpg');
    expect(entry?.document_photo_back_url).toBe('https://example.com/uploads/visa-page.jpg');
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
