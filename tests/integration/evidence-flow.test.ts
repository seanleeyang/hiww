import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder } from '../helpers/flows';

describe('evidence flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('uploads evidence for an order and lists it', async () => {
    const order = await createAcceptedOrder(ctx);

    const uploadResponse = await ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/evidence`,
      headers: authHeader(order.traveler),
      payload: {
        evidence_type: 'photo',
        url: 'https://example.com/package-proof.jpg',
      },
    });

    expect(uploadResponse.statusCode).toBe(201);
    expect(uploadResponse.json().success).toBe(true);

    const listResponse = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/evidence`,
      headers: authHeader(order.shopper),
    });

    expect(listResponse.statusCode).toBe(200);
    expect(listResponse.json().data).toHaveLength(1);
    expect(listResponse.json().data[0].url).toBe('https://example.com/package-proof.jpg');
  });

  it('does not let a non-participant read order evidence', async () => {
    const order = await createAcceptedOrder(ctx);
    const outsider = await createUser(ctx, { user_type: 'both' });

    const listResponse = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/evidence`,
      headers: authHeader(outsider),
    });

    expect(listResponse.statusCode).toBe(403);
  });
});
