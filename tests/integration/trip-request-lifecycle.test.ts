import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createTrip, createRequest, createAcceptedOrder } from '../helpers/flows';

describe('trip/want edit, cancel, and admin removal', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('lets a traveler edit their own published trip', async () => {
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const tripId = await createTrip(ctx, traveler);

    const res = await ctx.app.inject({
      method: 'PATCH',
      url: `/api/trips/${tripId}`,
      headers: authHeader(traveler),
      payload: { max_weight_kg: 30, note: 'Can carry a bit more this time' },
    });
    expect(res.statusCode).toBe(200);

    const trip = await ctx.db.selectFrom('trips').selectAll().where('id', '=', tripId).executeTakeFirst();
    expect(Number(trip?.max_weight_kg)).toBe(30);
    expect(trip?.note).toBe('Can carry a bit more this time');
  });

  it('blocks editing someone else\'s trip', async () => {
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const stranger = await createUser(ctx, { user_type: 'traveler' });
    const tripId = await createTrip(ctx, traveler);

    const res = await ctx.app.inject({
      method: 'PATCH',
      url: `/api/trips/${tripId}`,
      headers: authHeader(stranger),
      payload: { note: 'not mine to edit' },
    });
    expect(res.statusCode).toBe(403);
  });

  it('lets a traveler cancel their own trip, and it drops out of discovery', async () => {
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const viewer = await createUser(ctx, { user_type: 'shopper' });
    const tripId = await createTrip(ctx, traveler);

    const cancelRes = await ctx.app.inject({
      method: 'POST',
      url: `/api/trips/${tripId}/cancel`,
      headers: authHeader(traveler),
    });
    expect(cancelRes.statusCode).toBe(200);
    expect(cancelRes.json().data.status).toBe('cancelled');

    const feed = await ctx.app.inject({
      method: 'GET',
      url: '/api/discover/feed?type=trips',
      headers: authHeader(viewer),
    });
    const ids = feed.json().data.items.map((i: { id: string }) => i.id);
    expect(ids).not.toContain(tripId);
  });

  it('blocks cancelling a trip with an order still in progress', async () => {
    const order = await createAcceptedOrder(ctx);

    const res = await ctx.app.inject({
      method: 'POST',
      url: `/api/trips/${order.tripId}/cancel`,
      headers: authHeader(order.traveler),
    });
    expect(res.statusCode).toBe(400);
  });

  it('lets a shopper edit their own open want', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const requestId = await createRequest(ctx, shopper);

    const res = await ctx.app.inject({
      method: 'PATCH',
      url: `/api/requests/${requestId}`,
      headers: authHeader(shopper),
      payload: { budget: '200.00', quantity: 2 },
    });
    expect(res.statusCode).toBe(200);

    const want = await ctx.db.selectFrom('requests').selectAll().where('id', '=', requestId).executeTakeFirst();
    expect(want?.budget).toBe('200.00');
    expect(want?.quantity).toBe(2);
  });

  it('lets a shopper cancel their own want, and it drops out of discovery', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const viewer = await createUser(ctx, { user_type: 'traveler' });
    const requestId = await createRequest(ctx, shopper);

    const cancelRes = await ctx.app.inject({
      method: 'POST',
      url: `/api/requests/${requestId}/cancel`,
      headers: authHeader(shopper),
    });
    expect(cancelRes.statusCode).toBe(200);

    const feed = await ctx.app.inject({
      method: 'GET',
      url: '/api/discover/feed?type=wants',
      headers: authHeader(viewer),
    });
    const ids = feed.json().data.items.map((i: { id: string }) => i.id);
    expect(ids).not.toContain(requestId);
  });

  it('blocks editing or cancelling a want once it has an accepted offer', async () => {
    const order = await createAcceptedOrder(ctx);

    const editRes = await ctx.app.inject({
      method: 'PATCH',
      url: `/api/requests/${order.requestId}`,
      headers: authHeader(order.shopper),
      payload: { budget: '999.00' },
    });
    expect(editRes.statusCode).toBe(400);

    const cancelRes = await ctx.app.inject({
      method: 'POST',
      url: `/api/requests/${order.requestId}/cancel`,
      headers: authHeader(order.shopper),
    });
    expect(cancelRes.statusCode).toBe(400);
  });

  it('lets an admin remove any trip or want, bypassing the active-order guard', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const tripRes = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/trips/${order.tripId}/remove`,
      headers: authHeader(admin),
      payload: { reason: 'Reported as a scam listing' },
    });
    expect(tripRes.statusCode).toBe(200);

    const wantRes = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/requests/${order.requestId}/remove`,
      headers: authHeader(admin),
      payload: { reason: 'Duplicate post' },
    });
    expect(wantRes.statusCode).toBe(200);

    const trip = await ctx.db.selectFrom('trips').selectAll().where('id', '=', order.tripId).executeTakeFirst();
    const want = await ctx.db.selectFrom('requests').selectAll().where('id', '=', order.requestId).executeTakeFirst();
    expect(trip?.status).toBe('cancelled');
    expect(want?.status).toBe('cancelled');

    const auditRows = await ctx.db
      .selectFrom('audit_log')
      .selectAll()
      .where('action', 'in', ['trip.remove_by_admin', 'request.remove_by_admin'])
      .execute();
    expect(auditRows.length).toBe(2);
  });

  it('blocks a non-admin from removing a trip or want', async () => {
    const nonAdmin = await createUser(ctx, { user_type: 'traveler' });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const tripId = await createTrip(ctx, traveler);

    const res = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/trips/${tripId}/remove`,
      headers: authHeader(nonAdmin),
      payload: {},
    });
    expect(res.statusCode).toBe(403);
  });

  it('lists trips and requests for admin browsing', async () => {
    const admin = await createUser(ctx, { admin: true });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const tripId = await createTrip(ctx, traveler);
    const requestId = await createRequest(ctx, shopper);

    const trips = await ctx.app.inject({
      method: 'GET',
      url: '/api/admin/trips',
      headers: authHeader(admin),
    });
    expect(trips.statusCode).toBe(200);
    expect(trips.json().data.trips.some((t: { id: string }) => t.id === tripId)).toBe(true);

    const requests = await ctx.app.inject({
      method: 'GET',
      url: '/api/admin/requests',
      headers: authHeader(admin),
    });
    expect(requests.statusCode).toBe(200);
    expect(requests.json().data.requests.some((r: { id: string }) => r.id === requestId)).toBe(true);
  });
});
