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
    // item 120.00 -> reward floors to 50 (10% of 120 is only 12), fee 12,
    // so traveller_payout (item + reward) is 170.
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order); // → delivered

    let r = await recon(admin);
    expect(r.awaiting_payout.orders.some((o) => o.id === order.orderId)).toBe(true);
    expect(r.paid_out.payouts.some((p) => p.order_id === order.orderId)).toBe(false);

    const payout = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/payout',
      headers: authHeader(admin),
      payload: { order_id: order.orderId, method: 'wise', reference: 'W-123' },
    });
    expect(payout.statusCode).toBe(201);
    expect(payout.json().data.amount).toBe('170');

    r = await recon(admin);
    expect(r.awaiting_payout.orders.some((o) => o.id === order.orderId)).toBe(false);
    expect(r.paid_out.payouts.some((p) => p.order_id === order.orderId)).toBe(true);

    // A second attempt on the same order is rejected cleanly, not silently
    // accepted into a second payout.
    const secondPayout = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/payout',
      headers: authHeader(admin),
      payload: { order_id: order.orderId, method: 'wise', reference: 'W-456' },
    });
    expect(secondPayout.statusCode).toBe(409);
    expect(secondPayout.json().code).toBe('ALREADY_DONE');

    const audit = await ctx.app.inject({
      method: 'GET',
      url: `/api/admin/audit?action=order.payout&target_id=${order.orderId}`,
      headers: authHeader(admin),
    });
    const entry = audit.json().data.items[0];
    expect(entry.actor_id).toBe(admin.userId);
    expect(entry.metadata.reference).toBe('W-123');
    expect(entry.metadata.amount).toBe('170');
  });

  it('a concurrent double-payout attempt on the same order records exactly one payout', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);

    const attempt = (reference: string) =>
      ctx.app.inject({
        method: 'POST',
        url: '/api/payments/payout',
        headers: authHeader(admin),
        payload: { order_id: order.orderId, method: 'wise', reference },
      });
    const [r1, r2] = await Promise.all([attempt('W-RACE-1'), attempt('W-RACE-2')]);

    // Exactly one side wins (201); the other gets the same clean "already
    // done" error a sequential second attempt would — never a raw 500 from
    // the database's own unique-constraint rejection.
    const codes = [r1.statusCode, r2.statusCode].sort();
    expect(codes).toEqual([201, 409]);
    const loser = r1.statusCode === 409 ? r1 : r2;
    expect(loser.json().code).toBe('ALREADY_DONE');

    const payouts = await ctx.db.selectFrom('payouts').selectAll().where('order_id', '=', order.orderId).execute();
    expect(payouts).toHaveLength(1);
  });

  it('ignores a client-supplied amount and always pays out the server-computed traveller_payout', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx); // traveller_payout is 170
    await completeOrder(ctx, order);

    const payout = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/payout',
      headers: authHeader(admin),
      // Deliberately wrong amount — the server must not trust this.
      payload: { order_id: order.orderId, amount: '999999.00', method: 'wise', reference: 'W-456' },
    });
    expect(payout.statusCode).toBe(201);
    expect(payout.json().data.amount).toBe('170');

    const stored = await ctx.db
      .selectFrom('payouts')
      .selectAll()
      .where('id', '=', payout.json().data.id)
      .executeTakeFirst();
    expect(stored?.amount).toBe('170');
  });

  it('rejects a second payout for the same order', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);

    const body = { order_id: order.orderId, method: 'bank', reference: 'B-1' };
    const first = await ctx.app.inject({ method: 'POST', url: '/api/payments/payout', headers: authHeader(admin), payload: body });
    expect(first.statusCode).toBe(201);

    const second = await ctx.app.inject({ method: 'POST', url: '/api/payments/payout', headers: authHeader(admin), payload: body });
    expect(second.statusCode).toBe(409);
  });

  it("snapshots the traveler's own bank account onto the payout row, never accepting one from the request", async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx); // completeProfile gave the traveler a bank account
    await completeOrder(ctx, order);

    const payout = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/payout',
      headers: authHeader(admin),
      // Even if a client tried to sneak a destination account in, it must
      // be ignored — the server always reads the traveler's own profile.
      payload: {
        order_id: order.orderId,
        method: 'bank_transfer',
        reference: 'BT-1',
        bank_name: 'Some Other Bank',
        bank_account_number: '999999',
      },
    });
    expect(payout.statusCode).toBe(201);

    const stored = await ctx.db
      .selectFrom('payouts')
      .selectAll()
      .where('id', '=', payout.json().data.id)
      .executeTakeFirst();
    expect(stored?.bank_name).toBe('Kasikornbank (KBank)');
    expect(stored?.bank_account_number).toBe('1234567890');

    const r = await recon(admin);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const row = (r as any).paid_out.payouts.find((p: any) => p.order_id === order.orderId);
    expect(row.bank_name).toBe('Kasikornbank (KBank)');
    expect(row.bank_account_number).toBe('1234567890');
  });

  it('rejects a payout when the traveler has not added a bank account yet', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order);

    await ctx.db
      .updateTable('users')
      .set({ bank_name: null, bank_account_number: null })
      .where('id', '=', order.traveler.userId)
      .execute();

    const payout = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/payout',
      headers: authHeader(admin),
      payload: { order_id: order.orderId, method: 'wise', reference: 'W-NOPE' },
    });
    expect(payout.statusCode).toBe(400);

    const stored = await ctx.db.selectFrom('payouts').select(['id']).where('order_id', '=', order.orderId).executeTakeFirst();
    expect(stored).toBeUndefined();
  });

  it('rejects a payout for an order that is not delivered', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx); // still pending_payment

    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/payout',
      headers: authHeader(admin),
      payload: { order_id: order.orderId, method: 'wise', reference: 'X' },
    });
    expect(res.statusCode).toBe(409);
  });

  it('rejects a payout while the order has an open dispute', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    await completeOrder(ctx, order); // → delivered

    const dispute = await ctx.app.inject({
      method: 'POST',
      url: '/api/disputes',
      headers: authHeader(order.shopper),
      payload: { order_id: order.orderId, reason: 'Item arrived damaged' },
    });
    expect(dispute.statusCode).toBe(201);

    const payout = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/payout',
      headers: authHeader(admin),
      payload: { order_id: order.orderId, method: 'wise', reference: 'W-999' },
    });
    expect(payout.statusCode).toBe(409);

    const stored = await ctx.db.selectFrom('payouts').select(['id']).where('order_id', '=', order.orderId).executeTakeFirst();
    expect(stored).toBeUndefined();
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

  it('a new pending order adds its full shopper_total to awaiting_payment', async () => {
    const admin = await createUser(ctx, { admin: true });
    const before = await recon(admin);
    await createAcceptedOrder(ctx); // item 120 + reward 50 (floored) + fee 12 = 182

    const after = await recon(admin);
    expect(after.awaiting_payment.count).toBe(before.awaiting_payment.count + 1);

    const delta = Number(after.awaiting_payment.total) - Number(before.awaiting_payment.total);
    expect(delta).toBeCloseTo(182, 2);
  });
});
