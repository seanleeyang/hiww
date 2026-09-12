import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';

const submitPayload = {
  document_type: 'passport',
  document_id: 'ABC12345',
  first_name: 'Jane',
  last_name: 'Traveler',
  address: '123 Sukhumvit Rd, Bangkok',
  document_photo_url: 'https://example.com/uploads/id-front.jpg',
  selfie_photo_url: 'https://example.com/uploads/selfie.jpg',
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

  it('GET /api/me exposes kyc_submitted_at so the app can lock the form while a review is pending', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });
    const admin = await createUser(ctx, { admin: true });

    const before = await ctx.app.inject({ method: 'GET', url: '/api/me', headers: authHeader(user) });
    expect(before.json().data.kyc_status).toBe('pending');
    expect(before.json().data.kyc_submitted_at).toBeNull();

    await ctx.app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/submit',
      headers: authHeader(user),
      payload: submitPayload,
    });

    const afterSubmit = await ctx.app.inject({ method: 'GET', url: '/api/me', headers: authHeader(user) });
    expect(afterSubmit.json().data.kyc_status).toBe('pending');
    expect(afterSubmit.json().data.kyc_submitted_at).not.toBeNull();

    await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/users/${user.userId}/kyc-review`,
      headers: authHeader(admin),
      payload: { status: 'rejected', reason_code: 'photo_unclear' },
    });

    const afterReject = await ctx.app.inject({ method: 'GET', url: '/api/me', headers: authHeader(user) });
    expect(afterReject.json().data.kyc_status).toBe('rejected');
  });

  it('rejects a submission missing any required field', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });

    for (const omit of ['first_name', 'last_name', 'address', 'document_photo_url', 'selfie_photo_url']) {
      const payload = { ...submitPayload } as Record<string, unknown>;
      delete payload[omit];
      const res = await ctx.app.inject({
        method: 'POST',
        url: '/api/compliance/kyc/submit',
        headers: authHeader(user),
        payload,
      });
      expect(res.statusCode).toBe(400);
    }
  });

  it('persists the submitted document details and photos for an admin to review', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });
    const admin = await createUser(ctx, { admin: true });

    const submit = await ctx.app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/submit',
      headers: authHeader(user),
      payload: submitPayload,
    });
    expect(submit.statusCode).toBe(201);

    const row = await ctx.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', user.userId)
      .executeTakeFirst();
    expect(row?.kyc_document_type).toBe('passport');
    expect(row?.kyc_document_id).toBe('ABC12345');
    expect(row?.kyc_first_name).toBe('Jane');
    expect(row?.kyc_last_name).toBe('Traveler');
    expect(row?.kyc_address).toBe('123 Sukhumvit Rd, Bangkok');
    expect(row?.kyc_document_photo_url).toBe('https://example.com/uploads/id-front.jpg');
    expect(row?.kyc_selfie_photo_url).toBe('https://example.com/uploads/selfie.jpg');
    expect(row?.kyc_submitted_at).not.toBeNull();

    const reviews = await ctx.app.inject({
      method: 'GET',
      url: '/api/admin/reviews',
      headers: authHeader(admin),
    });
    const queue = reviews.json().data.queue as Array<Record<string, unknown>>;
    const entry = queue.find((q) => q.type === 'kyc' && q.user_id === user.userId);
    expect(entry).toBeDefined();
    expect(entry?.first_name).toBe('Jane');
    expect(entry?.last_name).toBe('Traveler');
    expect(entry?.address).toBe('123 Sukhumvit Rd, Bangkok');
    expect(entry?.document_photo_url).toBe('https://example.com/uploads/id-front.jpg');
    expect(entry?.selfie_photo_url).toBe('https://example.com/uploads/selfie.jpg');
  });

  it('notifies the user their submission was received', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });

    const submit = await ctx.app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/submit',
      headers: authHeader(user),
      payload: submitPayload,
    });
    expect(submit.statusCode).toBe(201);

    const notifications = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(user),
    });
    const items = notifications.json().data.items as Array<{ type: string }>;
    expect(items.some((n) => n.type === 'kyc_submitted')).toBe(true);
  });

  it('the AI check cross-references the submission with the document (mock analyzer)', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });
    const admin = await createUser(ctx, { admin: true });

    // The mock analyzer keys off the photo URLs — see MockKycAnalyzer.
    const submit = await ctx.app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/submit',
      headers: authHeader(user),
      payload: {
        ...submitPayload,
        document_photo_url: 'https://example.com/uploads/id-mismatch.jpg',
        selfie_photo_url: 'https://example.com/uploads/selfie-faceMismatch.jpg',
      },
    });
    expect(submit.statusCode).toBe(201);

    const row = await ctx.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', user.userId)
      .executeTakeFirst();
    expect(row?.kyc_ai_risk).toBe('high');
    expect(row?.kyc_ai_analysis).toBeDefined();
    expect((row?.kyc_ai_analysis as any).faceMatch).toBe('mismatch');

    const reviews = await ctx.app.inject({
      method: 'GET',
      url: '/api/admin/reviews',
      headers: authHeader(admin),
    });
    const queue = reviews.json().data.queue as Array<Record<string, unknown>>;
    const entry = queue.find((q) => q.type === 'kyc' && q.user_id === user.userId);
    expect((entry?.ai_analysis as any)?.faceMatch).toBe('mismatch');
    expect(entry?.ai_risk).toBe('high');
  });

  it('a clean submission comes back low risk from the AI check', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });

    const submit = await ctx.app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/submit',
      headers: authHeader(user),
      payload: submitPayload,
    });
    expect(submit.statusCode).toBe(201);

    const row = await ctx.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', user.userId)
      .executeTakeFirst();
    expect(row?.kyc_ai_risk).toBe('low');
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

  it('the admin console review action notifies the user with the custom note for "other"', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });
    const admin = await createUser(ctx, { admin: true });

    await ctx.app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/submit',
      headers: authHeader(user),
      payload: submitPayload,
    });

    const reject = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/users/${user.userId}/kyc-review`,
      headers: authHeader(admin),
      payload: { status: 'rejected', reason_code: 'other', note: 'Photo is too blurry to read' },
    });
    expect(reject.statusCode).toBe(200);

    const notifications = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(user),
    });
    const items = notifications.json().data.items as Array<{ type: string; body: string }>;
    const entry = items.find((n) => n.type === 'kyc_reviewed');
    expect(entry).toBeDefined();
    expect(entry?.body).toContain('Photo is too blurry to read');
  });

  it('rejecting with a fixed reason code notifies the user with the standard phrase, not raw text', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });
    const admin = await createUser(ctx, { admin: true });

    await ctx.app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/submit',
      headers: authHeader(user),
      payload: submitPayload,
    });

    const reject = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/users/${user.userId}/kyc-review`,
      headers: authHeader(admin),
      payload: { status: 'rejected', reason_code: 'selfie_mismatch' },
    });
    expect(reject.statusCode).toBe(200);

    const notifications = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(user),
    });
    const items = notifications.json().data.items as Array<{ type: string; body: string }>;
    const entry = items.find((n) => n.type === 'kyc_reviewed');
    expect(entry?.body).toContain('selfie did not appear to match');
  });

  it('rejecting without a reason code is rejected as invalid', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });
    const admin = await createUser(ctx, { admin: true });

    const reject = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/users/${user.userId}/kyc-review`,
      headers: authHeader(admin),
      payload: { status: 'rejected' },
    });
    expect(reject.statusCode).toBe(400);
  });

  it('rejecting with reason "other" but no note is rejected as invalid', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });
    const admin = await createUser(ctx, { admin: true });

    const reject = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/users/${user.userId}/kyc-review`,
      headers: authHeader(admin),
      payload: { status: 'rejected', reason_code: 'other' },
    });
    expect(reject.statusCode).toBe(400);
  });

  it('notifies every admin, with the AI-found reasons, when a submission is flagged medium/high risk', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });
    const admin = await createUser(ctx, { admin: true });

    const submit = await ctx.app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/submit',
      headers: authHeader(user),
      payload: {
        ...submitPayload,
        document_photo_url: 'https://example.com/uploads/id-mismatch.jpg',
        selfie_photo_url: 'https://example.com/uploads/selfie-faceMismatch.jpg',
      },
    });
    expect(submit.statusCode).toBe(201);

    const notifications = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(admin),
    });
    const items = notifications.json().data.items as Array<{ type: string; body: string }>;
    const entry = items.find((n) => n.type === 'kyc_ai_flagged');
    expect(entry).toBeDefined();
    // The account's own name (not the name printed on the document, which
    // can legitimately differ — see kyc_first_name/kyc_last_name).
    expect(entry?.body).toContain('Test User');
  });
});
