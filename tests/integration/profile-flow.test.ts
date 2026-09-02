import { makeTestApp, closeTestApp, authHeader, createUser, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, completeOrder } from '../helpers/flows';

describe('profile + reputation', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('/api/me exposes profile + reputation fields and PATCH updates them', async () => {
    const user = await createUser(ctx, { user_type: 'both' });

    const me = await ctx.app.inject({
      method: 'GET',
      url: '/api/me',
      headers: authHeader(user),
    });
    const body = me.json().data;
    expect(body.rating_avg).toBe(0);
    expect(body.rating_count).toBe(0);
    expect(body.delivered_count).toBe(0);
    expect(body.avatar_url).toBeNull();

    const patch = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: { home_city: 'Bangkok', avatar_url: 'https://example.com/a.png' },
    });
    expect(patch.statusCode).toBe(200);
    expect(patch.json().data.home_city).toBe('Bangkok');
    expect(patch.json().data.avatar_url).toBe('https://example.com/a.png');
  });

  it('rejects an empty or invalid profile update', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });
    const empty = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: {},
    });
    expect(empty.statusCode).toBe(400);

    const bad = await ctx.app.inject({
      method: 'PATCH',
      url: '/api/me',
      headers: authHeader(user),
      payload: { avatar_url: 'not-a-url' },
    });
    expect(bad.statusCode).toBe(400);
  });

  it('delivering an order bumps the traveler delivered_count and stage timestamps', async () => {
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);

    const finalOrder = await ctx.db
      .selectFrom('orders')
      .select(['confirmed_at', 'shipped_at', 'delivered_at'])
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(finalOrder?.confirmed_at).toBeTruthy();
    expect(finalOrder?.shipped_at).toBeTruthy();
    expect(finalOrder?.delivered_at).toBeTruthy();

    const traveler = await ctx.db
      .selectFrom('users')
      .select('delivered_count')
      .where('id', '=', order.traveler.userId)
      .executeTakeFirst();
    expect(Number(traveler?.delivered_count)).toBe(1);
  });
});
