import { makeTestApp, closeTestApp, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder } from '../helpers/flows';

describe('messages / inbox flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('participants can exchange messages; the inbox tracks unread counts', async () => {
    const order = await createAcceptedOrder(ctx);

    const send = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
      payload: { body: 'Hi! Any update on the purchase?' },
    });
    expect(send.statusCode).toBe(201);

    await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.traveler),
      payload: { body: 'Bought it today, shipping tomorrow.' },
    });

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    expect(list.json().data.items).toHaveLength(2);
    expect(list.json().data.items[0].sender_name).toBeTruthy();

    // Shopper's inbox: one unread (the traveler's reply).
    const inbox = await ctx.app.inject({
      method: 'GET',
      url: '/api/inbox',
      headers: authHeader(order.shopper),
    });
    const thread = inbox.json().data.items[0];
    expect(thread.order_id).toBe(order.orderId);
    expect(thread.unread_count).toBe(1);
    expect(thread.counterparty.id).toBe(order.traveler.userId);
    expect(thread.last_message.body).toContain('shipping tomorrow');

    // Mark read -> unread clears.
    await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/messages/read`,
      headers: authHeader(order.shopper),
    });
    const inbox2 = await ctx.app.inject({
      method: 'GET',
      url: '/api/inbox',
      headers: authHeader(order.shopper),
    });
    expect(inbox2.json().data.items[0].unread_count).toBe(0);
  });

  it('a non-participant cannot read or post', async () => {
    const order = await createAcceptedOrder(ctx);
    const outsider = (await createAcceptedOrder(ctx)).traveler;

    const read = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(outsider),
    });
    expect(read.statusCode).toBe(403);

    const post = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(outsider),
      payload: { body: 'hello' },
    });
    expect(post.statusCode).toBe(403);
  });

  it('orders with no messages do not appear in the inbox', async () => {
    const order = await createAcceptedOrder(ctx);
    const inbox = await ctx.app.inject({
      method: 'GET',
      url: '/api/inbox',
      headers: authHeader(order.shopper),
    });
    expect(inbox.json().data.items).toHaveLength(0);
  });

  it('a typing heartbeat shows up as counterparty_typing for the other participant only', async () => {
    const order = await createAcceptedOrder(ctx);

    const noOneTyping = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    expect(noOneTyping.json().data.counterparty_typing).toBe(false);

    const ping = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/typing`,
      headers: authHeader(order.traveler),
    });
    expect(ping.statusCode).toBe(200);

    // The shopper sees the traveler typing...
    const asShopper = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    expect(asShopper.json().data.counterparty_typing).toBe(true);

    // ...but the traveler doesn't see themselves as "typing" from their own view.
    const asTraveler = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.traveler),
    });
    expect(asTraveler.json().data.counterparty_typing).toBe(false);
  });
});
