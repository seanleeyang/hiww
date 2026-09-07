import { makeTestApp, closeTestApp, createUser, completeProfile, authHeader, type TestContext } from '../helpers/test-app';
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

  it('lets a traveler delete a trip with no offers on it, and it is gone for good', async () => {
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const tripId = await createTrip(ctx, traveler);

    const res = await ctx.app.inject({
      method: 'DELETE',
      url: `/api/trips/${tripId}`,
      headers: authHeader(traveler),
    });
    expect(res.statusCode).toBe(200);

    const trip = await ctx.db.selectFrom('trips').selectAll().where('id', '=', tripId).executeTakeFirst();
    expect(trip).toBeUndefined();
  });

  it('blocks deleting a trip that already has a pending (not yet accepted) offer', async () => {
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    await completeProfile(ctx, traveler);
    const tripId = await createTrip(ctx, traveler);
    const requestId = await createRequest(ctx, shopper);

    const offerRes = await ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(traveler),
      payload: {
        request_id: requestId,
        trip_id: tripId,
        quoted_price: '75.00',
        delivery_date: '2026-11-18T10:00:00.000Z',
      },
    });
    expect(offerRes.statusCode).toBe(201);

    const deleteRes = await ctx.app.inject({
      method: 'DELETE',
      url: `/api/trips/${tripId}`,
      headers: authHeader(traveler),
    });
    expect(deleteRes.statusCode).toBe(400);

    const trip = await ctx.db.selectFrom('trips').selectAll().where('id', '=', tripId).executeTakeFirst();
    expect(trip).toBeTruthy();
  });

  it('blocks deleting a trip that already has an accepted offer', async () => {
    const order = await createAcceptedOrder(ctx);

    const res = await ctx.app.inject({
      method: 'DELETE',
      url: `/api/trips/${order.tripId}`,
      headers: authHeader(order.traveler),
    });
    expect(res.statusCode).toBe(400);
  });

  it('blocks deleting someone else\'s trip', async () => {
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const stranger = await createUser(ctx, { user_type: 'traveler' });
    const tripId = await createTrip(ctx, traveler);

    const res = await ctx.app.inject({
      method: 'DELETE',
      url: `/api/trips/${tripId}`,
      headers: authHeader(stranger),
    });
    expect(res.statusCode).toBe(403);
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

  it('lets an admin cancel every live trip and want at once, leaving completed ones alone', async () => {
    const admin = await createUser(ctx, { admin: true });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const liveTripId = await createTrip(ctx, traveler);
    const liveRequestId = await createRequest(ctx, shopper);

    // A completed order's trip/request should survive the bulk cancel.
    const completedOrder = await createAcceptedOrder(ctx);
    await ctx.db.updateTable('trips').set({ status: 'completed' }).where('id', '=', completedOrder.tripId).execute();
    await ctx.db.updateTable('requests').set({ status: 'completed' }).where('id', '=', completedOrder.requestId).execute();

    const tripsRes = await ctx.app.inject({ method: 'POST', url: '/api/admin/trips/remove-all', headers: authHeader(admin) });
    expect(tripsRes.statusCode).toBe(200);
    expect(tripsRes.json().data.removed).toBeGreaterThanOrEqual(1);

    const wantsRes = await ctx.app.inject({ method: 'POST', url: '/api/admin/requests/remove-all', headers: authHeader(admin) });
    expect(wantsRes.statusCode).toBe(200);
    expect(wantsRes.json().data.removed).toBeGreaterThanOrEqual(1);

    const liveTrip = await ctx.db.selectFrom('trips').select(['status']).where('id', '=', liveTripId).executeTakeFirst();
    const liveRequest = await ctx.db.selectFrom('requests').select(['status']).where('id', '=', liveRequestId).executeTakeFirst();
    expect(liveTrip?.status).toBe('cancelled');
    expect(liveRequest?.status).toBe('cancelled');

    const completedTrip = await ctx.db.selectFrom('trips').select(['status']).where('id', '=', completedOrder.tripId).executeTakeFirst();
    const completedRequest = await ctx.db.selectFrom('requests').select(['status']).where('id', '=', completedOrder.requestId).executeTakeFirst();
    expect(completedTrip?.status).toBe('completed');
    expect(completedRequest?.status).toBe('completed');

    const auditRows = await ctx.db
      .selectFrom('audit_log')
      .selectAll()
      .where('action', 'in', ['trip.remove_by_admin', 'request.remove_by_admin'])
      .where('target_id', '=', 'bulk')
      .execute();
    expect(auditRows.length).toBe(2);
  });

  it('blocks a non-admin from bulk-cancelling trips or wants', async () => {
    const nonAdmin = await createUser(ctx, { user_type: 'traveler' });

    const tripsRes = await ctx.app.inject({ method: 'POST', url: '/api/admin/trips/remove-all', headers: authHeader(nonAdmin) });
    expect(tripsRes.statusCode).toBe(403);

    const wantsRes = await ctx.app.inject({ method: 'POST', url: '/api/admin/requests/remove-all', headers: authHeader(nonAdmin) });
    expect(wantsRes.statusCode).toBe(403);
  });

  it('lets the owner clear a cancelled trip/want from their own list, without touching its history', async () => {
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const tripId = await createTrip(ctx, traveler);
    const requestId = await createRequest(ctx, shopper);

    await ctx.app.inject({ method: 'POST', url: `/api/trips/${tripId}/cancel`, headers: authHeader(traveler) });
    await ctx.app.inject({ method: 'POST', url: `/api/requests/${requestId}/cancel`, headers: authHeader(shopper) });

    const tripArchive = await ctx.app.inject({ method: 'POST', url: `/api/trips/${tripId}/archive`, headers: authHeader(traveler) });
    expect(tripArchive.statusCode).toBe(200);
    const wantArchive = await ctx.app.inject({ method: 'POST', url: `/api/requests/${requestId}/archive`, headers: authHeader(shopper) });
    expect(wantArchive.statusCode).toBe(200);

    const trips = await ctx.app.inject({ method: 'GET', url: '/api/trips/mine', headers: authHeader(traveler) });
    expect(trips.json().data.items.some((t: { id: string }) => t.id === tripId)).toBe(false);
    const wants = await ctx.app.inject({ method: 'GET', url: '/api/requests/mine', headers: authHeader(shopper) });
    expect(wants.json().data.items.some((w: { id: string }) => w.id === requestId)).toBe(false);

    // The rows themselves — and their status — are untouched.
    const trip = await ctx.db.selectFrom('trips').select(['status', 'archived_at']).where('id', '=', tripId).executeTakeFirst();
    expect(trip?.status).toBe('cancelled');
    expect(trip?.archived_at).toBeTruthy();
    const want = await ctx.db.selectFrom('requests').select(['status', 'archived_at']).where('id', '=', requestId).executeTakeFirst();
    expect(want?.status).toBe('cancelled');
    expect(want?.archived_at).toBeTruthy();
  });

  it('blocks archiving a still-active trip or want', async () => {
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const tripId = await createTrip(ctx, traveler);
    const requestId = await createRequest(ctx, shopper);

    const tripRes = await ctx.app.inject({ method: 'POST', url: `/api/trips/${tripId}/archive`, headers: authHeader(traveler) });
    expect(tripRes.statusCode).toBe(400);
    const wantRes = await ctx.app.inject({ method: 'POST', url: `/api/requests/${requestId}/archive`, headers: authHeader(shopper) });
    expect(wantRes.statusCode).toBe(400);
  });

  it('blocks archiving someone else\'s trip or want', async () => {
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    const stranger = await createUser(ctx, { user_type: 'traveler' });
    const tripId = await createTrip(ctx, traveler);
    await ctx.app.inject({ method: 'POST', url: `/api/trips/${tripId}/cancel`, headers: authHeader(traveler) });

    const res = await ctx.app.inject({ method: 'POST', url: `/api/trips/${tripId}/archive`, headers: authHeader(stranger) });
    expect(res.statusCode).toBe(403);
  });
});
