import 'dotenv/config';
import fastify, { FastifyInstance } from 'fastify';
import { Kysely } from 'kysely';
import { createDatabase } from '@/db/connection';
import { registerAuthRoutes } from '@/modules/auth/routes';
import { registerOffersRoutes } from '@/modules/offers/routes';
import { registerOrdersRoutes } from '@/modules/orders/routes';
import { registerDeliveryRoutes } from '@/modules/orders/delivery-routes';
import { registerRequestsRoutes } from '@/modules/requests/routes';
import { registerTripsRoutes } from '@/modules/trips/routes';
import type { Database } from '@/types/database';

describe('delivery and release flow', () => {
  let app: ReturnType<typeof fastify>;
  let db: Kysely<Database>;
  let travelerToken: string;
  let shopperToken: string;
  let orderId: string;

  beforeEach(async () => {
    db = createDatabase();
    app = fastify();

    app.addHook('preHandler', async (request: any) => {
      request.db = db;
      const authHeader = request.headers.authorization;
      if (typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
        const { verifyToken } = await import('@/utils/auth');
        request.userId = verifyToken(authHeader.slice(7)).userId;
      } else {
        request.userId = request.headers['x-user-id'] as string;
      }
    });

    await app.register(async (instance: FastifyInstance) => {
      registerAuthRoutes(instance);
      registerRequestsRoutes(instance);
      registerTripsRoutes(instance);
      registerOffersRoutes(instance);
      registerOrdersRoutes(instance);
      registerDeliveryRoutes(instance);
    });

    await app.ready();

    const travelerRegister = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: 'traveler-delivery@example.com',
        full_name: 'Traveler Delivery',
        user_type: 'traveler',
        password: 'SecurePass123!',
      },
    });

    const shopperRegister = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: 'shopper-delivery@example.com',
        full_name: 'Shopper Delivery',
        user_type: 'shopper',
        password: 'SecurePass123!',
      },
    });

    travelerToken = travelerRegister.json().data.token;
    shopperToken = shopperRegister.json().data.token;

    const requestResponse = await app.inject({
      method: 'POST',
      url: '/api/requests',
      headers: { authorization: `Bearer ${shopperToken}` },
      payload: {
        item_description: 'Luxury skincare set',
        source_country: 'US',
        category: 'beauty',
        estimated_weight_kg: 2,
        budget: '150.00',
      },
    });

    const requestId = requestResponse.json().data.id;

    const tripResponse = await app.inject({
      method: 'POST',
      url: '/api/trips',
      headers: { authorization: `Bearer ${travelerToken}` },
      payload: {
        departure_country: 'US',
        arrival_country: 'FR',
        departure_date: '2026-11-15T08:00:00.000Z',
        return_date: '2026-11-22T08:00:00.000Z',
        max_weight_kg: 25,
        max_items: 3,
      },
    });

    const tripId = tripResponse.json().data.id;

    const offerResponse = await app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: { authorization: `Bearer ${travelerToken}` },
      payload: {
        request_id: requestId,
        quoted_price: '120.00',
        delivery_date: '2026-11-18T10:00:00.000Z',
      },
    });

    const offerId = offerResponse.json().data.id;

    const acceptResponse = await app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/accept`,
      headers: { authorization: `Bearer ${shopperToken}` },
      payload: {
        trip_id: tripId,
        item_description: 'Luxury skincare set',
        quantity: 1,
        unit_price: '120.00',
      },
    });

    orderId = acceptResponse.json().data.order_id;

    await db
      .updateTable('orders')
      .set({ status: 'confirmed' })
      .where('id', '=', orderId)
      .execute();
  });

  afterEach(async () => {
    await app.close();
    await db.destroy();
  });

  it('marks delivery and releases funds to the traveler', async () => {
    const deliverResponse = await app.inject({
      method: 'POST',
      url: `/api/orders/${orderId}/deliver`,
      headers: { authorization: `Bearer ${travelerToken}` },
      payload: {
        note: 'Package delivered at destination',
      },
    });

    expect(deliverResponse.statusCode).toBe(200);
    expect(deliverResponse.json().success).toBe(true);

    const orderAfterDelivery = await db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', orderId)
      .executeTakeFirst();

    expect(orderAfterDelivery?.status).toBe('in_transit');

    const releaseResponse = await app.inject({
      method: 'POST',
      url: `/api/orders/${orderId}/release`,
      headers: { authorization: `Bearer ${shopperToken}` },
      payload: {
        note: 'Received package and releasing funds',
      },
    });

    expect(releaseResponse.statusCode).toBe(200);
    expect(releaseResponse.json().success).toBe(true);

    const finalOrder = await db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', orderId)
      .executeTakeFirst();

    expect(finalOrder?.status).toBe('delivered');
  });
});
