import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, type MarketplaceOrder } from '../helpers/flows';

/**
 * The test run uses the mock receipt analyzer (AI_RECEIPT_ANALYZER defaults to
 * `mock`), which keys risk off the image URL: `suspicious` → high, `flagme` →
 * medium, anything else → low.
 */
describe('AI receipt check', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  async function confirmedOrder(): Promise<{ order: MarketplaceOrder; admin: Awaited<ReturnType<typeof createUser>> }> {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    const confirm = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/confirm',
      headers: authHeader(admin),
      payload: { order_id: order.orderId },
    });
    expect(confirm.statusCode).toBe(200);
    return { order, admin };
  }

  const uploadReceipt = (order: MarketplaceOrder, imageUrl: string, itemPhotoUrl?: string) =>
    ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/purchase-proof`,
      headers: authHeader(order.traveler),
      payload: itemPhotoUrl ? { image_url: imageUrl, item_photo_url: itemPhotoUrl } : { image_url: imageUrl },
    });

  const reviewQueue = async (admin: Awaited<ReturnType<typeof createUser>>) => {
    const res = await ctx.app.inject({ method: 'GET', url: '/api/admin/reviews', headers: authHeader(admin) });
    expect(res.statusCode).toBe(200);
    return res.json().data.queue as any[];
  };

  it('a clean receipt records a low-risk assessment and does not hit the queue', async () => {
    const { order, admin } = await confirmedOrder();
    await uploadReceipt(order, 'https://example.com/uploads/receipt-ok.jpg');

    const row = await ctx.db
      .selectFrom('orders')
      .select(['receipt_risk', 'receipt_analysis'])
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(row?.receipt_risk).toBe('low');
    expect((row?.receipt_analysis as any).model).toBe('mock');

    const queue = await reviewQueue(admin);
    expect(queue.some((q) => q.type === 'receipt' && q.order_id === order.orderId)).toBe(false);
  });

  it('a suspicious receipt is flagged high, queued for the operator, and audited', async () => {
    const { order, admin } = await confirmedOrder();
    await uploadReceipt(order, 'https://example.com/uploads/suspicious-receipt.png');

    const row = await ctx.db
      .selectFrom('orders')
      .select(['receipt_risk'])
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(row?.receipt_risk).toBe('high');

    const queue = await reviewQueue(admin);
    const entry = queue.find((q) => q.type === 'receipt' && q.order_id === order.orderId);
    expect(entry).toBeDefined();
    expect(entry.risk).toBe('high');
    expect(entry.flags.length).toBeGreaterThan(0);

    const audit = await ctx.app.inject({
      method: 'GET',
      url: `/api/admin/audit?action=order.receipt_flag&target_id=${order.orderId}`,
      headers: authHeader(admin),
    });
    expect(audit.json().data.items).toHaveLength(1);

    // The order still advanced — the check never blocks it.
    const ship = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/deliver`,
      headers: authHeader(order.traveler),
      payload: {},
    });
    expect(ship.statusCode).toBe(200);
  });

  it('the operator can clear a flag out of the queue', async () => {
    const { order, admin } = await confirmedOrder();
    await uploadReceipt(order, 'https://example.com/uploads/flagme.jpg');

    let queue = await reviewQueue(admin);
    expect(queue.some((q) => q.type === 'receipt' && q.order_id === order.orderId)).toBe(true);

    const clear = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/orders/${order.orderId}/clear-receipt-flag`,
      headers: authHeader(admin),
    });
    expect(clear.statusCode).toBe(200);

    queue = await reviewQueue(admin);
    expect(queue.some((q) => q.type === 'receipt' && q.order_id === order.orderId)).toBe(false);
  });

  it('participants never see the risk assessment; the admin does', async () => {
    const { order, admin } = await confirmedOrder();
    await uploadReceipt(order, 'https://example.com/uploads/suspicious-x.jpg');

    const asShopper = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}`,
      headers: authHeader(order.shopper),
    });
    const shopperView = asShopper.json().data;
    expect(shopperView.purchase_proof_url).toBeTruthy(); // photo yes
    expect(shopperView.receipt_risk).toBeUndefined(); // assessment no
    expect(shopperView.receipt_analysis).toBeUndefined();

    const asAdmin = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}`,
      headers: authHeader(admin),
    });
    expect(asAdmin.json().data.receipt_risk).toBe('high');
  });

  it('stores an item photo alongside the receipt, visible to participants and admin', async () => {
    const { order, admin } = await confirmedOrder();
    await uploadReceipt(order, 'https://example.com/uploads/receipt-ok.jpg', 'https://example.com/uploads/item.jpg');

    const row = await ctx.db
      .selectFrom('orders')
      .select(['item_photo_url', 'receipt_analysis'])
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    expect(row?.item_photo_url).toBe('https://example.com/uploads/item.jpg');
    const analysis = row?.receipt_analysis as any;
    expect(analysis.itemPhotoAssessment).toBe('match');
    expect(analysis.extracted.language).toBe('English');

    const asShopper = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}`,
      headers: authHeader(order.shopper),
    });
    // The photo is visible to participants — only the AI risk verdict is admin-only.
    expect(asShopper.json().data.item_photo_url).toBe('https://example.com/uploads/item.jpg');

    const queue = await reviewQueue(admin);
    expect(queue.some((q) => q.type === 'receipt' && q.order_id === order.orderId)).toBe(false);
  });

  it('flags a mismatched item photo and surfaces it in the review queue', async () => {
    const { order, admin } = await confirmedOrder();
    await uploadReceipt(order, 'https://example.com/uploads/receipt-ok.jpg', 'https://example.com/uploads/mismatch-item.jpg');

    const row = await ctx.db
      .selectFrom('orders')
      .select(['receipt_analysis'])
      .where('id', '=', order.orderId)
      .executeTakeFirst();
    const analysis = row?.receipt_analysis as any;
    expect(analysis.itemPhotoAssessment).toBe('mismatch');
    expect(analysis.flags).toContain('Item photo does not appear to match the request');

    const queue = await reviewQueue(admin);
    const entry = queue.find((q) => q.type === 'receipt' && q.order_id === order.orderId);
    expect(entry).toBeDefined();
    expect(entry.item_photo_assessment).toBe('mismatch');
    expect(entry.item_photo_url).toBe('https://example.com/uploads/mismatch-item.jpg');
  });
});
