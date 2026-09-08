import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder } from '../helpers/flows';

describe('backend text localizes to the caller\'s Accept-Language', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('renders an AppError message in Thai only when Accept-Language: th is sent', async () => {
    const user = await createUser(ctx);
    const bogusId = '00000000-0000-0000-0000-000000000000';

    const en = await ctx.app.inject({
      method: 'GET',
      url: `/api/trips/${bogusId}`,
      headers: authHeader(user),
    });
    expect(en.statusCode).toBe(404);
    expect(en.json().error).toBe('Trip not found');

    const th = await ctx.app.inject({
      method: 'GET',
      url: `/api/trips/${bogusId}`,
      headers: { ...authHeader(user), 'accept-language': 'th' },
    });
    expect(th.statusCode).toBe(404);
    expect(th.json().error).toBe('ไม่พบทริปนี้');
    expect(th.json().code).toBe('NOT_FOUND');
  });

  it('renders a notification subject/body in Thai from stored params', async () => {
    // Accepting the offer notifies the traveler (offer_accepted:by_shopper).
    const order = await createAcceptedOrder(ctx);

    const en = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(order.traveler),
    });
    expect(en.statusCode).toBe(200);
    const enItem = en.json().data.items.find((i: { type: string }) => i.type === 'offer_accepted');
    expect(enItem.subject).toBe('Your offer was accepted');

    const th = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: { ...authHeader(order.traveler), 'accept-language': 'th' },
    });
    expect(th.statusCode).toBe(200);
    const thItem = th.json().data.items.find((i: { type: string }) => i.type === 'offer_accepted');
    expect(thItem.subject).toBe('ข้อเสนอของคุณได้รับการยอมรับแล้ว');
    expect(thItem.body).toContain('ผู้ซื้อ');
  });
});
