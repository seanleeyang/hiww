import { makeTestApp, closeTestApp, authHeader, createUser, type TestContext } from '../helpers/test-app';

// These tests share a database with the rest of the suite (no per-test reset),
// so every assertion is scoped to entities this test created — never global
// counts — except where a deliberately unique country/category code is used.

describe('discovery feed + route match', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });
  afterEach(async () => {
    await closeTestApp(ctx);
  });

  async function postTrip(user: { token: string }, body: Record<string, unknown>): Promise<string> {
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/trips',
      headers: authHeader(user as never),
      payload: {
        departure_country: 'TH',
        arrival_country: 'JP',
        departure_date: '2026-11-12T08:00:00.000Z',
        return_date: '2026-11-19T08:00:00.000Z',
        max_weight_kg: 8,
        max_items: 5,
        ...body,
      },
    });
    if (res.statusCode !== 201) throw new Error(res.body);
    return res.json().data.id as string;
  }

  async function postWant(user: { token: string }, body: Record<string, unknown>): Promise<string> {
    const res = await ctx.app.inject({
      method: 'POST',
      url: '/api/requests',
      headers: authHeader(user as never),
      payload: {
        item_description: 'Nike Dunk Low Panda, size US 9',
        source_country: 'JP',
        category: 'sneakers',
        estimated_weight_kg: 1.2,
        budget: '6500.00',
        ...body,
      },
    });
    if (res.statusCode !== 201) throw new Error(res.body);
    return res.json().data.id as string;
  }

  it('interleaves trips and wants, enriches with owner + match counts + earn estimate', async () => {
    const traveler = await createUser(ctx, { user_type: 'both' });
    const shopper = await createUser(ctx, { user_type: 'both' });

    const tripId = await postTrip(traveler, { title: 'Tokyo run', arrival_city: 'Tokyo' });
    const wantId = await postWant(shopper, { title: 'Nike Dunk Panda', need_by: '2026-12-01T00:00:00.000Z' });

    const forTraveler = await ctx.app.inject({
      method: 'GET',
      url: '/api/discover/feed',
      headers: authHeader(traveler),
    });
    const want = forTraveler
      .json()
      .data.items.find((i: { kind: string; id: string }) => i.kind === 'want' && i.id === wantId);
    expect(want).toBeTruthy();
    expect(want.shopper.id).toBe(shopper.userId);
    expect(want.match_count).toBeGreaterThanOrEqual(1);

    const forShopper = await ctx.app.inject({
      method: 'GET',
      url: '/api/discover/feed',
      headers: authHeader(shopper),
    });
    const trip = forShopper
      .json()
      .data.items.find((i: { kind: string; id: string }) => i.kind === 'trip' && i.id === tripId);
    expect(trip.traveler.id).toBe(traveler.userId);
    expect(trip.match_count).toBeGreaterThanOrEqual(1);
    // earn estimate includes this want: 6500 * 0.08 = 520
    expect(Number(trip.earn_estimate)).toBeGreaterThanOrEqual(520);
  });

  it('does not show the caller their own trips or wants', async () => {
    const me = await createUser(ctx, { user_type: 'both' });
    const myTrip = await postTrip(me, {});
    const myWant = await postWant(me, {});

    const feed = await ctx.app.inject({
      method: 'GET',
      url: '/api/discover/feed',
      headers: authHeader(me),
    });
    const items = feed.json().data.items as Array<{ id: string; traveler?: { id: string }; shopper?: { id: string } }>;
    expect(items.some((i) => i.id === myTrip || i.id === myWant)).toBe(false);
    expect(items.some((i) => i.traveler?.id === me.userId || i.shopper?.id === me.userId)).toBe(false);
  });

  it('filters wants by category', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const viewer = await createUser(ctx, { user_type: 'traveler' });
    await postWant(shopper, { category: 'sneakers' });
    const beautyId = await postWant(shopper, {
      category: 'discotest-beauty',
      item_description: 'SK-II facial essence 230ml',
    });

    const res = await ctx.app.inject({
      method: 'GET',
      url: '/api/discover/feed?type=wants&category=discotest-beauty',
      headers: authHeader(viewer),
    });
    const items = res.json().data.items;
    expect(items).toHaveLength(1);
    expect(items[0].id).toBe(beautyId);
  });

  it('route-match counts travelers heading to a country', async () => {
    const t1 = await createUser(ctx, { user_type: 'traveler' });
    const t2 = await createUser(ctx, { user_type: 'traveler' });
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    // Unique arrival code so the count is not polluted by other suites.
    await postTrip(t1, { arrival_country: 'QZ' });
    await postTrip(t2, { departure_country: 'QZ', arrival_country: 'SG' });

    const res = await ctx.app.inject({
      method: 'GET',
      url: '/api/discover/route-match?source_country=QZ',
      headers: authHeader(shopper),
    });
    expect(res.json().data.count).toBe(2);
    expect(res.json().data.sample.length).toBe(2);
  });
});
