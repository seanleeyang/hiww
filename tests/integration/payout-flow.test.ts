import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, completeOrder } from '../helpers/flows';

// Integration tests share one database, so assert on *this order* and on
// *deltas*, never on absolute reconciliation totals.
describe('payouts + reconciliation', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  interface Recon {
    awaiting_payment: { count: number; total: string; claimed: number };
    awaiting_payout: { count: number; total: string; orders: Array<{ id: string; total_price: string }> };
    paid_out: { count: number; total: string; payouts: Array<{ order_id: string }> };
  }

  const recon = async (admin: Parameters<typeof authHeader>[0]): Promise<Recon> => {
    const res = await ctx.app.inject({
      method: 'GET',
      url: '/api/ops/reconciliation',
      headers: authHeader(admin),
    });
    expect(res.statusCode).toBe(200);
    return res.json().data as Recon;
  };

  it('a delivered order shows as awaiting payout, then moves to paid once recorded', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx); // total_price 120.00, fees 9.60
    await completeOrder(ctx, order); // → delivered

    let r = await recon(admin);
    expect(r.awaiting_payout.orders.some((o) => o.id === order.orderId)).toBe(true);
    expect(r.paid_out.payouts.some((p) => p.order_id === order.orderId)).toBe(false);

    const payout = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/payout',
      headers: authHeader(admin),
      payload: { order_id: order.orderId, amount: '120.00', method: 'wise', reference: 'W-123' },
    });
    expect(payout.statusCode).toBe(201);

    r = await recon(admin);
    expect(r.awaiting_payout.orders.some((o) => o.id === order.orderId)).toBe(false);
    expect(r.paid_out.payouts.some((p) => p.order_id === order.orderId)).toBe(true);

    const audit = await ctx.app.inject({
      method: 'GET',
      url: `/api/admin/audit?action=order.payout&target_id=${order.orderId}`,
      headers: authHeader(admin),
    });
    const entry = audit.json().data.items[0];
    expect(entry.actor_id).toBe(admin.userId);
    expect(entry.metadata.reference).toBe('W-123');
  });

  it('rejects a second payout for the same order', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);

    const body = { order_id: order.orderId, amount: '120.00', method: 'bank', reference: 'B-1' };
    const first = await ctx.app.inject({ method: 'POST', url: '/api/payments/payout', headers: authHeader(admin), payload: body });
    expect(first.statusCode).toBe(201);

    const second = await ctx.app.inject({ method: 'POST', url: '/api/payments/payout', headers: authHeader(admin), payload: body });
    expect(second.statusCode).toBe(409);
  });

  it('rejects a payout for an order that is not delivered', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx); // still pending_payment

    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/payout',
      headers: authHeader(admin),
      payload: { order_id: order.orderId, amount: '120.00', method: 'wise', reference: 'X' },
    });
    expect(res.statusCode).toBe(409);
  });

  it('reconciliation and payout are admin-only', async () => {
    const plain = await createUser(ctx, { user_type: 'both' });

    const recon401 = await ctx.app.inject({ method: 'GET', url: '/api/ops/reconciliation' });
    expect(recon401.statusCode).toBe(401);

    const recon403 = await ctx.app.inject({ method: 'GET', url: '/api/ops/reconciliation', headers: authHeader(plain) });
    expect(recon403.statusCode).toBe(403);

    const payout403 = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/payout',
      headers: authHeader(plain),
      payload: { order_id: '00000000-0000-0000-0000-000000000000', amount: '1.00', method: 'x', reference: 'y' },
    });
    expect(payout403.statusCode).toBe(403);
  });

  it('a new pending order adds its goods+fee total to awaiting_payment', async () => {
    const admin = await createUser(ctx, { admin: true });
    const before = await recon(admin);
    await createAcceptedOrder(ctx); // 120.00 goods + 9.60 fee

    const after = await recon(admin);
    expect(after.awaiting_payment.count).toBe(before.awaiting_payment.count + 1);

    const delta = Number(after.awaiting_payment.total) - Number(before.awaiting_payment.total);
    expect(delta).toBeCloseTo(129.6, 2);
  });
});
