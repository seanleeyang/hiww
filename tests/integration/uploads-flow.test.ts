import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { __setFileStore, type FileStore } from '@/services/storage';

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
