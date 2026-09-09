import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, type MarketplaceOrder } from '../helpers/flows';

/**
 * There's no background scheduler in this pilot — the reminder is fired
 * lazily whenever the traveler's own client polls their notification feed
 * (see src/services/upload-reminder.ts). These tests drive that same route.
 */
describe('upload reminder', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  async function confirmedOrder(): Promise<MarketplaceOrder> {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    const confirm = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/confirm',
      headers: authHeader(admin),
      payload: { order_id: order.orderId },
    });
    expect(confirm.statusCode).toBe(200);
    return order;
  }

  const notifications = async (order: MarketplaceOrder) => {
    const res = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(order.traveler),
    });
    expect(res.statusCode).toBe(200);
    return res.json().data.items as any[];
  };

  it('reminds the traveler to upload once payment is confirmed, with days left until the trip returns', async () => {
    const order = await confirmedOrder();

    const items = await notifications(order);
    const reminder = items.find((n) => n.type === 'upload_reminder' && n.order_id === order.orderId);
    expect(reminder).toBeDefined();
    expect(reminder.body).toMatch(/day.*left to upload the item photo and receipt/i);
  });

  it('does not send a second reminder for the same order right away', async () => {
    const order = await confirmedOrder();

    await notifications(order); // first poll fires the reminder
    const items = await notifications(order); // second poll, moments later

    const reminders = items.filter((n) => n.type === 'upload_reminder' && n.order_id === order.orderId);
    expect(reminders).toHaveLength(1);
  });

  it('does not remind about orders that are not awaiting upload', async () => {
    const order = await createAcceptedOrder(ctx); // still pending_payment
    const items = await notifications(order);
    expect(items.some((n) => n.type === 'upload_reminder')).toBe(false);
  });

  it("exposes the trip's return date on the order for the client's own countdown", async () => {
    const order = await confirmedOrder();
    const res = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}`,
      headers: authHeader(order.traveler),
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().data.trip_return_date).toBeTruthy();
  });
});
