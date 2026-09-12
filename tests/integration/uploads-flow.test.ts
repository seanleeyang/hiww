import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { __setFileStore, type FileStore } from '@/services/storage';
import { signUploadKey } from '@/utils/signed-url';

// A 1x1 transparent PNG.
const PNG_1PX = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64'
);

interface Part {
  name: string;
  filename?: string;
  contentType?: string;
  data: Buffer | string;
}

function multipart(parts: Part[]): { body: Buffer; contentType: string } {
  const boundary = `----hiwwtest${Math.random().toString(16).slice(2)}`;
  const chunks: Buffer[] = [];
  for (const p of parts) {
    let head = `--${boundary}\r\nContent-Disposition: form-data; name="${p.name}"`;
    if (p.filename) head += `; filename="${p.filename}"`;
    head += '\r\n';
    if (p.contentType) head += `Content-Type: ${p.contentType}\r\n`;
    head += '\r\n';
    chunks.push(Buffer.from(head, 'utf8'));
    chunks.push(Buffer.isBuffer(p.data) ? p.data : Buffer.from(p.data, 'utf8'));
    chunks.push(Buffer.from('\r\n', 'utf8'));
  }
  chunks.push(Buffer.from(`--${boundary}--\r\n`, 'utf8'));
  return { body: Buffer.concat(chunks), contentType: `multipart/form-data; boundary=${boundary}` };
}

describe('uploads flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('stores an image and serves it back at the returned URL', async () => {
    const user = await createUser(ctx);
    const { body, contentType } = multipart([
      { name: 'file', filename: 'photo.png', contentType: 'image/png', data: PNG_1PX },
    ]);

    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/uploads',
      headers: { ...authHeader(user), 'content-type': contentType },
      payload: body,
    });

    expect(res.statusCode).toBe(201);
    const url = res.json().data.url as string;
    expect(url).toMatch(/\/uploads\/[0-9a-f-]+\.png$/);

    const path = new URL(url).pathname;
    const fetched = await ctx.app.inject({ method: 'GET', url: path });
    expect(fetched.statusCode).toBe(200);
    expect(fetched.headers['content-type']).toContain('image/png');
    expect(fetched.rawPayload.equals(PNG_1PX)).toBe(true);
  });

  it('rejects an unauthenticated upload', async () => {
    const { body, contentType } = multipart([
      { name: 'file', filename: 'photo.png', contentType: 'image/png', data: PNG_1PX },
    ]);

    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/uploads',
      headers: { 'content-type': contentType },
      payload: body,
    });

    expect(res.statusCode).toBe(401);
  });

  it('rejects a non-image content type', async () => {
    const user = await createUser(ctx);
    const { body, contentType } = multipart([
      { name: 'file', filename: 'notes.txt', contentType: 'text/plain', data: 'hello' },
    ]);

    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/uploads',
      headers: { ...authHeader(user), 'content-type': contentType },
      payload: body,
    });

    expect(res.statusCode).toBe(400);
  });

  it('rejects an image over the size limit', async () => {
    const user = await createUser(ctx);
    const tooBig = Buffer.alloc(6 * 1024 * 1024, 1);
    const { body, contentType } = multipart([
      { name: 'file', filename: 'big.png', contentType: 'image/png', data: tooBig },
    ]);

    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/uploads',
      headers: { ...authHeader(user), 'content-type': contentType },
      payload: body,
    });

    expect(res.statusCode).toBe(400);
  });

  it('refuses to serve a KYC photo with no signature, an expired one, or a tampered one — but accepts a real one', async () => {
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const admin = await createUser(ctx, { admin: true });
    const { body, contentType } = multipart([
      { name: 'file', filename: 'id-front.png', contentType: 'image/png', data: PNG_1PX },
    ]);
    const upload = await ctx.app.inject({
      method: 'POST',
      url: '/api/uploads',
      headers: { ...authHeader(traveler), 'content-type': contentType },
      payload: body,
    });
    const rawUrl = upload.json().data.url as string;
    const path = new URL(rawUrl).pathname;
    const key = path.split('/uploads/')[1];

    await ctx.db
      .updateTable('users')
      .set({ kyc_document_photo_url: rawUrl })
      .where('id', '=', traveler.userId)
      .execute();

    // No signature at all.
    const noSig = await ctx.app.inject({ method: 'GET', url: path });
    expect(noSig.statusCode).toBe(403);

    // Tampered signature — flip a character.
    const { exp, sig } = signUploadKey(key, 900);
    const badSig = sig.slice(0, -1) + (sig.at(-1) === '0' ? '1' : '0');
    const tampered = await ctx.app.inject({ method: 'GET', url: `${path}?exp=${exp}&sig=${badSig}` });
    expect(tampered.statusCode).toBe(403);

    // Expired — signed for a moment already in the past.
    const expired = signUploadKey(key, -1);
    const expiredRes = await ctx.app.inject({
      method: 'GET',
      url: `${path}?exp=${expired.exp}&sig=${expired.sig}`,
    });
    expect(expiredRes.statusCode).toBe(403);

    // The real thing, exactly as GET /api/admin/reviews would hand it out.
    const reviews = await ctx.app.inject({ method: 'GET', url: '/api/admin/reviews', headers: authHeader(admin) });
    const entry = (reviews.json().data.queue as Array<Record<string, unknown>>).find(
      (q) => q.type === 'kyc' && q.user_id === traveler.userId
    );
    const signedPath = new URL(entry!.document_photo_url as string).pathname + new URL(entry!.document_photo_url as string).search;
    const ok = await ctx.app.inject({ method: 'GET', url: signedPath });
    expect(ok.statusCode).toBe(200);
    expect(ok.rawPayload.equals(PNG_1PX)).toBe(true);
  });

  it('an ordinary (non-KYC) upload needs no signature at all', async () => {
    const user = await createUser(ctx);
    const { body, contentType } = multipart([
      { name: 'file', filename: 'avatar.png', contentType: 'image/png', data: PNG_1PX },
    ]);
    const upload = await ctx.app.inject({
      method: 'POST',
      url: '/api/uploads',
      headers: { ...authHeader(user), 'content-type': contentType },
      payload: body,
    });
    const path = new URL(upload.json().data.url as string).pathname;

    const res = await ctx.app.inject({ method: 'GET', url: path });
    expect(res.statusCode).toBe(200);
  });

  it('rejects a key that does not look like one of ours, before ever touching the database', async () => {
    const res = await ctx.app.inject({ method: 'GET', url: '/uploads/not-a-real-upload-key.exe' });
    expect(res.statusCode).toBe(404);
  });

  it('rejects a multi-segment path traversal attempt at the routing level', async () => {
    const res = await ctx.app.inject({ method: 'GET', url: '/uploads/../../etc/passwd' });
    expect(res.statusCode).toBe(404);
  });

  it('with a remote store, returns the store\'s absolute URL as-is', async () => {
    const puts: Array<{ key: string; contentType: string; size: number }> = [];
    const remote: FileStore = {
      urlIsRelative: false,
      async put(key, body, contentType) {
        puts.push({ key, contentType, size: body.length });
      },
      url: (key) => `https://cdn.hiww.test/${key}`,
    };

    await closeTestApp(ctx);
    __setFileStore(remote);
    ctx = await makeTestApp();
    try {
      const user = await createUser(ctx);
      const { body, contentType } = multipart([
        { name: 'file', filename: 'photo.png', contentType: 'image/png', data: PNG_1PX },
      ]);
      const res = await ctx.app.inject({
        method: 'POST',
        url: '/api/uploads',
        headers: { ...authHeader(user), 'content-type': contentType },
        payload: body,
      });

      expect(res.statusCode).toBe(201);
      const url = res.json().data.url as string;
      expect(url).toMatch(/^https:\/\/cdn\.hiww\.test\/[0-9a-f-]+\.png$/);
      expect(puts).toHaveLength(1);
      expect(puts[0].contentType).toBe('image/png');
      expect(puts[0].size).toBe(PNG_1PX.length);
    } finally {
      __setFileStore(undefined);
    }
  });
});
