import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, completeOrder } from '../helpers/flows';

describe('audit log', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  async function audit(admin: Parameters<typeof authHeader>[0], query = '') {
    const res = await ctx.app.inject({
      method: 'GET',
      url: `/api/admin/audit${query}`,
      headers: authHeader(admin),
    });
    expect(res.statusCode).toBe(200);
    return res.json().data.items as Array<{
      action: string;
      target_type: string;
      target_id: string;
      actor_id: string | null;
      actor_role: string | null;
      summary: string;
      metadata: Record<string, unknown>;
    }>;
  }

  it('records the full money path with the acting user on each entry', async () => {
    const order = await createAcceptedOrder(ctx); // logs order.create
    await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/claim-payment`,
      headers: authHeader(order.shopper),
      payload: {},
    });
    await completeOrder(ctx, order); // payment.confirm + order.ship + order.release

    const admin = await createUser(ctx, { admin: true });
    const entries = await audit(admin, `?target_id=${order.orderId}`);

    const byAction = Object.fromEntries(entries.map((e) => [e.action, e]));
    expect(Object.keys(byAction).sort()).toEqual(
      ['order.create', 'order.payment_claim', 'order.release', 'order.ship', 'payment.confirm'].sort(),
    );

    // The shopper accepted the offer…
    expect(byAction['order.create'].actor_id).toBe(order.shopper.userId);
    // …an admin confirmed the payment…
    expect(byAction['payment.confirm'].actor_role).toBe('admin');
    expect(byAction['payment.confirm'].metadata.total_price).toBeDefined();
    // …the traveler shipped…
    expect(byAction['order.ship'].actor_id).toBe(order.traveler.userId);
    // …and the shopper released.
    expect(byAction['order.release'].actor_id).toBe(order.shopper.userId);
    expect(byAction['order.release'].metadata.traveler_id).toBe(order.traveler.userId);
  });

  it('records admin review-queue actions', async () => {
    const admin = await createUser(ctx, { admin: true });
    const user = await createUser(ctx, { user_type: 'shopper' });

    await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/users/${user.userId}/kyc-review`,
      headers: authHeader(admin),
      payload: { status: 'approved', note: 'looks fine' },
    });
    await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/users/${user.userId}/flag`,
      headers: authHeader(admin),
      payload: { risk_status: 'flagged', reason: 'test' },
    });

    const entries = await audit(admin, `?target_id=${user.userId}`);
    const actions = entries.map((e) => e.action).sort();
    expect(actions).toEqual(['kyc.review', 'user.flag']);
    expect(entries.every((e) => e.actor_id === admin.userId)).toBe(true);
  });

  it('is admin-only', async () => {
    const plain = await createUser(ctx, { user_type: 'both' });

    const anon = await ctx.app.inject({ method: 'GET', url: '/api/admin/audit' });
    expect(anon.statusCode).toBe(401);

    const forbidden = await ctx.app.inject({
      method: 'GET',
      url: '/api/admin/audit',
      headers: authHeader(plain),
    });
    expect(forbidden.statusCode).toBe(403);
  });

  it('filters by action', async () => {
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);
    const admin = await createUser(ctx, { admin: true });

    const confirms = await audit(admin, '?action=payment.confirm');
    expect(confirms.length).toBeGreaterThanOrEqual(1);
    expect(confirms.every((e) => e.action === 'payment.confirm')).toBe(true);
  });
});
