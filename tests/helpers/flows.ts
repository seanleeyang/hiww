import { createUser, completeProfile, authHeader, type TestContext, type TestUser } from './test-app';

/**
 * Helpers that drive the real HTTP routes to build up marketplace state for
 * tests. Every step goes through the app so auth and validation are exercised.
 */

export async function createRequest(ctx: TestContext, shopper: TestUser): Promise<string> {
  const res = await ctx.app.inject({
    method: 'POST',
    url: '/api/requests',
    headers: authHeader(shopper),
    payload: {
      item_description: 'Luxury skincare set for gifting',
      source_country: 'US',
      category: 'beauty',
      estimated_weight_kg: 2,
      budget: '150.00',
      destination_country: 'TH',
    },
  });
  if (res.statusCode !== 201) throw new Error(`createRequest failed (${res.statusCode}): ${res.body}`);
  return res.json().data.id as string;
}

export async function createTrip(ctx: TestContext, traveler: TestUser): Promise<string> {
  const res = await ctx.app.inject({
    method: 'POST',
    url: '/api/trips',
    headers: authHeader(traveler),
    payload: {
      departure_country: 'US',
      arrival_country: 'FR',
      departure_date: '2026-11-15T08:00:00.000Z',
      return_date: '2026-11-22T08:00:00.000Z',
      max_weight_kg: 25,
      max_items: 3,
    },
  });
  if (res.statusCode !== 201) throw new Error(`createTrip failed (${res.statusCode}): ${res.body}`);
  return res.json().data.id as string;
}

export interface MarketplaceOrder {
  shopper: TestUser;
  traveler: TestUser;
  requestId: string;
  tripId: string;
  offerId: string;
  orderId: string;
}

/**
 * Full shopper-initiated flow up to an order in `pending_payment`:
 * register both parties, post a request and a trip, make an offer, accept it.
 */
export async function createAcceptedOrder(ctx: TestContext): Promise<MarketplaceOrder> {
  const shopper = await createUser(ctx, { user_type: 'shopper' });
  const traveler = await createUser(ctx, { user_type: 'traveler' });
  await completeProfile(ctx, shopper);
  await completeProfile(ctx, traveler);

  const requestId = await createRequest(ctx, shopper);
  const tripId = await createTrip(ctx, traveler);

  const offerRes = await ctx.app.inject({
    method: 'POST',
    url: '/api/offers',
    headers: authHeader(traveler),
    payload: {
      request_id: requestId,
      trip_id: tripId,
      quoted_price: '120.00',
      delivery_date: '2026-11-18T10:00:00.000Z',
    },
  });
  if (offerRes.statusCode !== 201) throw new Error(`createOffer failed (${offerRes.statusCode}): ${offerRes.body}`);
  const offerId = offerRes.json().data.id as string;

  const acceptRes = await ctx.app.inject({
    method: 'POST',
    url: `/api/offers/${offerId}/accept`,
    headers: authHeader(shopper),
    payload: {},
  });
  if (acceptRes.statusCode !== 200) throw new Error(`acceptOffer failed (${acceptRes.statusCode}): ${acceptRes.body}`);
  const orderId = acceptRes.json().data.order_id as string;

  return { shopper, traveler, requestId, tripId, offerId, orderId };
}

/** Move an order straight to a given status (bypasses payment for setup only). */
export async function forceOrderStatus(ctx: TestContext, orderId: string, status: string): Promise<void> {
  await ctx.db
    .updateTable('orders')
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    .set({ status: status as any, updated_at: new Date() })
    .where('id', '=', orderId)
    .execute();
}

/**
 * Drive an accepted order all the way to `delivered` through the real routes:
 * confirm payment (admin), traveler uploads a purchase receipt, traveler ships,
 * shopper confirms receipt.
 */
export async function completeOrder(ctx: TestContext, order: MarketplaceOrder): Promise<void> {
  const admin = await createUser(ctx, { admin: true });
  const confirm = await ctx.app.inject({
    method: 'POST',
    url: '/api/payments/confirm',
    headers: authHeader(admin),
    payload: { order_id: order.orderId },
  });
  if (confirm.statusCode !== 200) throw new Error(`confirm failed (${confirm.statusCode}): ${confirm.body}`);

  const proof = await ctx.app.inject({
    method: 'POST',
    url: `/api/orders/${order.orderId}/purchase-proof`,
    headers: authHeader(order.traveler),
    payload: { image_url: 'https://example.com/receipt.jpg' },
  });
  if (proof.statusCode !== 200) throw new Error(`purchase-proof failed (${proof.statusCode}): ${proof.body}`);

  const ship = await ctx.app.inject({
    method: 'POST',
    url: `/api/orders/${order.orderId}/deliver`,
    headers: authHeader(order.traveler),
    payload: {},
  });
  if (ship.statusCode !== 200) throw new Error(`deliver failed (${ship.statusCode}): ${ship.body}`);

  const release = await ctx.app.inject({
    method: 'POST',
    url: `/api/orders/${order.orderId}/release`,
    headers: authHeader(order.shopper),
    payload: { image_url: 'https://example.com/delivery-proof.jpg' },
  });
  if (release.statusCode !== 200) throw new Error(`release failed (${release.statusCode}): ${release.body}`);
}
