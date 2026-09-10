import { makeTestApp, closeTestApp, type TestContext } from '../helpers/test-app';

describe('health check', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('reports ok with a live database', async () => {
    const res = await ctx.app.inject({ method: 'GET', url: '/health' });

    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.status).toBe('ok');
    expect(body.database).toBe('ok');
    expect(body.env).toMatchObject({ database_url_present: expect.any(Boolean) });
  });
});
