import { makeTestApp, closeTestApp, createUser, completeProfile, type TestContext } from '../helpers/test-app';
import { createTrip, createRequest } from '../helpers/flows';

describe('a signed-out guest can browse read-only routes', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('sees the discover feed without an Authorization header', async () => {
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    await completeProfile(ctx, traveler);
    const tripId = await createTrip(ctx, traveler);

    const res = await ctx.app.inject({ method: 'GET', url: '/api/discover/feed' });
    expect(res.statusCode).toBe(200);
    const items = res.json().data.items as Array<{ id: string; kind: string }>;
    // Regression check: an unconditional `!= request.userId` filter would
    // bind SQL NULL for a guest and silently exclude every row.
    expect(items.some((i) => i.kind === 'trip' && i.id === tripId)).toBe(true);
  });

  it('views one trip and one want without an Authorization header', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    await completeProfile(ctx, shopper);
    await completeProfile(ctx, traveler);
    const tripId = await createTrip(ctx, traveler);
    const requestId = await createRequest(ctx, shopper);

    const tripRes = await ctx.app.inject({ method: 'GET', url: `/api/trips/${tripId}` });
    expect(tripRes.statusCode).toBe(200);

    const wantRes = await ctx.app.inject({ method: 'GET', url: `/api/requests/${requestId}` });
    expect(wantRes.statusCode).toBe(200);

    const reviewsRes = await ctx.app.inject({ method: 'GET', url: `/api/users/${traveler.userId}/reviews` });
    expect(reviewsRes.statusCode).toBe(200);
  });

  it('still requires auth to edit or delete a trip at the same path pattern', async () => {
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    await completeProfile(ctx, traveler);
    const tripId = await createTrip(ctx, traveler);

    const patchRes = await ctx.app.inject({
      method: 'PATCH',
      url: `/api/trips/${tripId}`,
      payload: { note: 'should not work' },
    });
    expect(patchRes.statusCode).toBe(401);

    const deleteRes = await ctx.app.inject({ method: 'DELETE', url: `/api/trips/${tripId}` });
    expect(deleteRes.statusCode).toBe(401);
  });

  it('still requires auth to post a trip or a want', async () => {
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/trips',
      payload: {
        departure_country: 'TH',
        arrival_country: 'JP',
        departure_date: '2026-11-12T08:00:00.000Z',
        return_date: '2026-11-19T08:00:00.000Z',
        max_weight_kg: 8,
        max_items: 5,
      },
    });
    expect(res.statusCode).toBe(401);
  });
});
