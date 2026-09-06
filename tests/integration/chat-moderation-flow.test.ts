import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder } from '../helpers/flows';

/**
 * The test run uses the mock chat moderation analyzer (AI_CHAT_MODERATION
 * defaults to `mock`), which keys risk off the message body: `suspicious` →
 * high, `flagme` → medium, anything else → low. The instant regex pass runs
 * regardless of the mock/real split — a phone number or email always trips it.
 */
describe('AI chat moderation', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  const send = (order: Awaited<ReturnType<typeof createAcceptedOrder>>, body: string) =>
    ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
      payload: { body },
    });

  const reviewQueue = async (admin: Awaited<ReturnType<typeof createUser>>) => {
    const res = await ctx.app.inject({ method: 'GET', url: '/api/admin/reviews', headers: authHeader(admin) });
    expect(res.statusCode).toBe(200);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return res.json().data.queue as any[];
  };

  it('an ordinary message sends cleanly with no warning and never hits the queue', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, 'Hi! Any update on the purchase?');
    expect(res.statusCode).toBe(201);
    expect(res.json().data.warning).toBeNull();

    const queue = await reviewQueue(admin);
    expect(queue.some((q) => q.type === 'message')).toBe(false);
  });

  it('a message with a phone number is warned, sent anyway, and queued for the operator', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, "Call me at 081-234-5678, it's easier");
    expect(res.statusCode).toBe(201);
    expect(res.json().data.warning).toBeTruthy();

    // The message still exists and is readable — it's flagged, not blocked.
    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    expect(list.json().data.items).toHaveLength(1);
    expect(list.json().data.items[0].body).toContain('081-234-5678');

    const queue = await reviewQueue(admin);
    const entry = queue.find((q) => q.type === 'message' && q.order_id === order.orderId);
    expect(entry).toBeDefined();
    expect(entry.risk).toBe('medium');
    expect(entry.flags.length).toBeGreaterThan(0);
  });

  it('a message the AI check calls high-risk is queued even without a regex match', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, 'this is a suspicious message with no contact info');
    expect(res.statusCode).toBe(201);
    expect(res.json().data.warning).toBeNull(); // regex pass found nothing

    const queue = await reviewQueue(admin);
    const entry = queue.find((q) => q.type === 'message' && q.order_id === order.orderId);
    expect(entry).toBeDefined();
    expect(entry.risk).toBe('high');
  });

  it('the operator can clear a flag out of the queue', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const sendRes = await send(order, 'flagme please, testing the review queue');
    const messageId = sendRes.json().data.id;

    let queue = await reviewQueue(admin);
    expect(queue.some((q) => q.type === 'message' && q.id === messageId)).toBe(true);

    const clear = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/messages/${messageId}/clear-flag`,
      headers: authHeader(admin),
    });
    expect(clear.statusCode).toBe(200);

    queue = await reviewQueue(admin);
    expect(queue.some((q) => q.type === 'message' && q.id === messageId)).toBe(false);
  });

  it('participants never see the flag; the admin does', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    await send(order, 'my email is shady@example.com');

    const asShopper = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    expect(asShopper.json().data.items[0].flag_risk).toBeUndefined();

    const queue = await reviewQueue(admin);
    expect(queue.some((q) => q.type === 'message' && q.order_id === order.orderId)).toBe(true);
  });
});
