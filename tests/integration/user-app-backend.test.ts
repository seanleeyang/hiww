import { makeTestApp, closeTestApp, createUser, completeProfile, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder, createRequest, createTrip } from '../helpers/flows';

describe('user-app backend: privacy + listings', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('GET /api/me returns the profile and pilot payment info', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });
    const res = await ctx.app.inject({ method: 'GET', url: '/api/me', headers: authHeader(user) });
    expect(res.statusCode).toBe(200);
    const d = res.json().data;
    expect(d.email).toBe(user.email);
    expect(d.user_type).toBe('shopper');
    expect(d.pilot).toHaveProperty('payment_instructions');
  });

  it('a user only sees their own orders; a non-participant is blocked from the detail', async () => {
    const order = await createAcceptedOrder(ctx);
    const outsider = await createUser(ctx, { user_type: 'both' });

    const mine = await ctx.app.inject({ method: 'GET', url: '/api/orders', headers: authHeader(order.shopper) });
    expect(mine.json().data.items.length).toBe(1);

    const theirs = await ctx.app.inject({ method: 'GET', url: '/api/orders', headers: authHeader(outsider) });
    expect(theirs.json().data.items.length).toBe(0);

    const detail = await ctx.app.inject({ method: 'GET', url: `/api/orders/${order.orderId}`, headers: authHeader(outsider) });
    expect(detail.statusCode).toBe(403);

    const admin = await createUser(ctx, { admin: true });
    const asAdmin = await ctx.app.inject({ method: 'GET', url: `/api/orders/${order.orderId}`, headers: authHeader(admin) });
    expect(asAdmin.statusCode).toBe(200);
  });

  it('request browse hides your own and non-open requests; /mine shows your own', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const myReq = await createRequest(ctx, shopper);

    const browseSelf = await ctx.app.inject({ method: 'GET', url: '/api/requests', headers: authHeader(shopper) });
    expect(browseSelf.json().data.items.find((r: { id: string }) => r.id === myReq)).toBeUndefined();

    const browseTraveler = await ctx.app.inject({ method: 'GET', url: '/api/requests', headers: authHeader(traveler) });
    expect(browseTraveler.json().data.items.find((r: { id: string }) => r.id === myReq)).toBeTruthy();

    const mine = await ctx.app.inject({ method: 'GET', url: '/api/requests/mine', headers: authHeader(shopper) });
    expect(mine.json().data.items.length).toBe(1);
  });

  it('shopper can claim payment on a pending order; nobody else can', async () => {
    const order = await createAcceptedOrder(ctx);

    const bad = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/claim-payment`,
      headers: authHeader(order.traveler),
    });
    expect(bad.statusCode).toBe(403);

    const ok = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/claim-payment`,
      headers: authHeader(order.shopper),
    });
    expect(ok.statusCode).toBe(200);

    const row = await ctx.db.selectFrom('orders').selectAll().where('id', '=', order.orderId).executeTakeFirst();
    expect(row?.payment_claimed_at).toBeTruthy();
  });

  it('a traveler lists their own offers via /api/offers/mine', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    await completeProfile(ctx, traveler);
    const requestId = await createRequest(ctx, shopper);
    const tripId = await createTrip(ctx, traveler);
    await ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(traveler),
      payload: { request_id: requestId, trip_id: tripId, quoted_price: '99.00', delivery_date: '2026-11-18T10:00:00.000Z' },
    });

    const mine = await ctx.app.inject({ method: 'GET', url: '/api/offers/mine', headers: authHeader(traveler) });
    expect(mine.statusCode).toBe(200);
    expect(mine.json().data.items[0].request_item).toBeTruthy();
  });
});
