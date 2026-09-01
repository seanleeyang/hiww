import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';

describe('notifications flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('creates and lists notifications for a user', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });

    const createResponse = await ctx.app.inject({
      method: 'POST',
      url: '/api/notifications',
      headers: authHeader(user),
      payload: { type: 'email', subject: 'Order confirmed', body: 'Your order has been confirmed.' },
    });
    expect(createResponse.statusCode).toBe(201);

    const listResponse = await ctx.app.inject({
      method: 'GET',
      url: `/api/notifications/${user.userId}`,
      headers: authHeader(user),
    });

    expect(listResponse.statusCode).toBe(200);
    expect(listResponse.json().data.length).toBeGreaterThanOrEqual(1);
  });

  it('requires authentication to create a notification', async () => {
    const response = await ctx.app.inject({
      method: 'POST',
      url: '/api/notifications',
      payload: { type: 'email', subject: 'x', body: 'y' },
    });
    expect(response.statusCode).toBe(401);
  });
});
