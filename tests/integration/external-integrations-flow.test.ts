import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder } from '../helpers/flows';

describe('external integrations flow', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('an admin creates a provider-backed payment session', async () => {
    const order = await createAcceptedOrder(ctx);
    const admin = await createUser(ctx, { admin: true });

    const paymentResponse = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/initiate',
      headers: authHeader(admin),
      payload: { order_id: order.orderId },
    });

    expect(paymentResponse.statusCode).toBe(202);
    expect(paymentResponse.json().data.provider).toBe('mock_payment_provider');
    expect(paymentResponse.json().data.payment_id).toContain('payment_');
  });

  it('a user submits an identity verification payload to the provider', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });

    const verificationResponse = await ctx.app.inject({
      method: 'POST',
      url: '/api/identity/verify',
      headers: authHeader(user),
      payload: { document_type: 'passport', document_id: 'ABC12345' },
    });

    expect(verificationResponse.statusCode).toBe(200);
    expect(verificationResponse.json().success).toBe(true);
    expect(verificationResponse.json().data.provider).toBe('mock_identity_provider');
    expect(verificationResponse.json().data.status).toBe('verified');
  });

  it('a normal user cannot initiate a payment session', async () => {
    const order = await createAcceptedOrder(ctx);

    const response = await ctx.app.inject({
      method: 'POST',
      url: '/api/payments/initiate',
      headers: authHeader(order.shopper),
      payload: { order_id: order.orderId },
    });

    expect(response.statusCode).toBe(403);
  });
});
