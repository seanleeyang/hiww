import { makeTestApp, closeTestApp, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, completeOrder } from '../helpers/flows';

describe('reviews flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('a delivered order can be reviewed once, and updates the reviewee rating', async () => {
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);

    const res = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/review`,
      headers: authHeader(order.shopper),
      payload: { rating: 5, comment: 'Perfect handover in Bangkok' },
    });
    expect(res.statusCode).toBe(201);

    const again = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/review`,
      headers: authHeader(order.shopper),
      payload: { rating: 3 },
    });
    expect(again.statusCode).toBe(409);

    const traveler = await ctx.db
      .selectFrom('users')
      .select(['rating_sum', 'rating_count'])
      .where('id', '=', order.traveler.userId)
      .executeTakeFirst();
    expect(Number(traveler?.rating_sum)).toBe(5);
    expect(Number(traveler?.rating_count)).toBe(1);

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/users/${order.traveler.userId}/reviews`,
      headers: authHeader(order.shopper),
    });
    expect(list.statusCode).toBe(200);
    const body = list.json().data;
    expect(body.user.rating_avg).toBe(5);
    expect(body.items).toHaveLength(1);
    expect(body.items[0].comment).toContain('Bangkok');
  });

  it('rejects a review before delivery and from a non-participant', async () => {
    const order = await createAcceptedOrder(ctx);

    const early = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/review`,
      headers: authHeader(order.shopper),
      payload: { rating: 4 },
    });
    expect(early.statusCode).toBe(409);

    await completeOrder(ctx, order);
    const outsider = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/review`,
      headers: authHeader((await createAcceptedOrder(ctx)).shopper),
      payload: { rating: 1 },
    });
    expect(outsider.statusCode).toBe(403);
  });

  it('exposes can_review and my_review on the order', async () => {
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);

    const before = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}`,
      headers: authHeader(order.traveler),
    });
    expect(before.json().data.can_review).toBe(true);
    expect(before.json().data.counterparty.id).toBe(order.shopper.userId);

    await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/review`,
      headers: authHeader(order.traveler),
      payload: { rating: 4 },
    });

    const after = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}`,
      headers: authHeader(order.traveler),
    });
    expect(after.json().data.can_review).toBe(false);
    expect(after.json().data.my_review.rating).toBe(4);
  });
});
