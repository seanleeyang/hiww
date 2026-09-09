import {
  makeTestApp,
  closeTestApp,
  createUser,
  completeProfile,
  authHeader,
  type TestContext,
} from '../helpers/test-app';
import { createAcceptedOrder, createRequest, createTrip, type MarketplaceOrder } from '../helpers/flows';
import { __setPushSender } from '@/services/push';
import { MockPushSender } from '@/services/push/mock-push-sender';

describe('push notifications', () => {
  let ctx: TestContext;
  let pushSender: MockPushSender;

  beforeEach(async () => {
    ctx = await makeTestApp();
    pushSender = new MockPushSender();
    __setPushSender(pushSender);
  });

  afterEach(async () => {
    __setPushSender(undefined);
    await closeTestApp(ctx);
  });

  const registerDevice = (user: Awaited<ReturnType<typeof createUser>>, token: string, platform = 'android') =>
    ctx.app.inject({
      method: 'POST',
      url: '/api/devices/register',
      headers: authHeader(user),
      payload: { token, platform },
    });

  it('registers and unregisters a device token', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });

    const register = await registerDevice(shopper, 'device-token-1');
    expect(register.statusCode).toBe(200);

    const row = await ctx.db
      .selectFrom('device_tokens')
      .select(['user_id', 'platform'])
      .where('token', '=', 'device-token-1')
      .executeTakeFirst();
    expect(row?.user_id).toBe(shopper.userId);
    expect(row?.platform).toBe('android');

    const unregister = await ctx.app.inject({
      method: 'POST',
      url: '/api/devices/unregister',
      headers: authHeader(shopper),
      payload: { token: 'device-token-1' },
    });
    expect(unregister.statusCode).toBe(200);

    const gone = await ctx.db
      .selectFrom('device_tokens')
      .select(['token'])
      .where('token', '=', 'device-token-1')
      .executeTakeFirst();
    expect(gone).toBeUndefined();
  });

  it("re-registering the same token re-points it at whoever is now signed in", async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const other = await createUser(ctx, { user_type: 'shopper' });

    await registerDevice(shopper, 'shared-device');
    await registerDevice(other, 'shared-device');

    const rows = await ctx.db.selectFrom('device_tokens').select(['user_id']).where('token', '=', 'shared-device').execute();
    expect(rows).toHaveLength(1);
    expect(rows[0]?.user_id).toBe(other.userId);
  });

  it('a signed-in user cannot unregister a device they do not own', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const attacker = await createUser(ctx, { user_type: 'shopper' });
    await registerDevice(shopper, 'victim-device');

    await ctx.app.inject({
      method: 'POST',
      url: '/api/devices/unregister',
      headers: authHeader(attacker),
      payload: { token: 'victim-device' },
    });

    const stillThere = await ctx.db
      .selectFrom('device_tokens')
      .select(['token'])
      .where('token', '=', 'victim-device')
      .executeTakeFirst();
    expect(stillThere).toBeDefined();
  });

  it('pushes the shopper the payment countdown the instant the order is created', async () => {
    const shopper = await createUser(ctx, { user_type: 'shopper' });
    const traveler = await createUser(ctx, { user_type: 'traveler' });
    await completeProfile(ctx, shopper);
    await completeProfile(ctx, traveler);
    await registerDevice(shopper, 'shopper-device');

    const requestId = await createRequest(ctx, shopper);
    const tripId = await createTrip(ctx, traveler);
    const offerRes = await ctx.app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: authHeader(traveler),
      payload: { request_id: requestId, trip_id: tripId, quoted_price: '120.00', delivery_date: '2026-11-18T10:00:00.000Z' },
    });
    const offerId = offerRes.json().data.id as string;

    pushSender.sent.length = 0; // ignore anything from setup above
    const accept = await ctx.app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/accept`,
      headers: authHeader(shopper),
      payload: {},
    });
    expect(accept.statusCode).toBe(200);

    expect(pushSender.sent).toHaveLength(1);
    expect(pushSender.sent[0]!.tokens).toEqual(['shopper-device']);
    expect(pushSender.sent[0]!.message.body).toMatch(/pay within \d+ minutes/i);
    expect(pushSender.sent[0]!.message.data?.link).toBe(`/orders/${accept.json().data.order_id}`);
  });

  it('pushes the traveler the daily upload reminder once payment is confirmed', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order: MarketplaceOrder = await createAcceptedOrder(ctx);
    await registerDevice(order.traveler, 'traveler-device');

    await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/confirm',
      headers: authHeader(admin),
      payload: { order_id: order.orderId },
    });

    pushSender.sent.length = 0;
    await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(order.traveler),
    });

    expect(pushSender.sent).toHaveLength(1);
    expect(pushSender.sent[0]!.tokens).toEqual(['traveler-device']);
    expect(pushSender.sent[0]!.message.title).toMatch(/upload/i);
  });

  it('prunes a token the provider reports as dead', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order: MarketplaceOrder = await createAcceptedOrder(ctx);
    await registerDevice(order.traveler, 'dead-device-token');

    await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/confirm',
      headers: authHeader(admin),
      payload: { order_id: order.orderId },
    });
    await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(order.traveler),
    });

    const row = await ctx.db
      .selectFrom('device_tokens')
      .select(['token'])
      .where('token', '=', 'dead-device-token')
      .executeTakeFirst();
    expect(row).toBeUndefined();
  });
});
