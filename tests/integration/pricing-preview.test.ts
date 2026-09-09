import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';

describe('GET /api/pricing/preview', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('returns the worked example for a ฿1,000 item', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });

    const res = await ctx.app.inject({
      method: 'GET',
      url: '/api/pricing/preview?item_price=1000',
      headers: authHeader(user),
    });

    expect(res.statusCode).toBe(200);
    const data = res.json().data;
    expect(data.itemPrice).toBe('1000');
    expect(data.travellerReward).toBe('100');
    expect(data.serviceFee).toBe('100');
    expect(data.shopperTotal).toBe('1200');
    expect(data.travellerPayout).toBe('1100');
    expect(data.platformGrossRevenue).toBe('100');
    expect(data.currency).toBe('THB');
  });

  it('requires authentication', async () => {
    const res = await ctx.app.inject({ method: 'GET', url: '/api/pricing/preview?item_price=1000' });
    expect(res.statusCode).toBe(401);
  });

  it('rejects a malformed item_price', async () => {
    const user = await createUser(ctx, { user_type: 'shopper' });
    const res = await ctx.app.inject({
      method: 'GET',
      url: '/api/pricing/preview?item_price=not-a-number',
      headers: authHeader(user),
    });
    expect(res.statusCode).toBe(400);
  });
});
