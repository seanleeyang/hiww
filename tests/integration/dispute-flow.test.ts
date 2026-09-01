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
import { registerDisputesRoutes } from '@/modules/disputes/routes';
import type { Database } from '@/types/database';

describe('dispute flow', () => {
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
      registerDisputesRoutes(instance);
    });

    await app.ready();

    const travelerRegister = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: 'traveler-dispute@example.com',
        full_name: 'Traveler Dispute',
        user_type: 'traveler',
        password: 'SecurePass123!',
      },
    });

    const shopperRegister = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: 'shopper-dispute@example.com',
        full_name: 'Shopper Dispute',
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

  it('allows a shopper to open a dispute and resolves it', async () => {
    const disputeResponse = await app.inject({
      method: 'POST',
      url: '/api/disputes',
      headers: { authorization: `Bearer ${shopperToken}` },
      payload: {
        order_id: orderId,
        reason: 'Item arrived damaged and late',
      },
    });

    expect(disputeResponse.statusCode).toBe(201);
    const disputeId = disputeResponse.json().data.id;

    const resolutionResponse = await app.inject({
      method: 'POST',
      url: `/api/disputes/${disputeId}/resolve`,
      headers: { authorization: `Bearer ${travelerToken}` },
      payload: {
        resolution: 'Partial refund approved due to delay and damage.',
        status: 'resolved',
      },
    });

    expect(resolutionResponse.statusCode).toBe(200);
    expect(resolutionResponse.json().success).toBe(true);

    const dispute = await db
      .selectFrom('disputes')
      .selectAll()
      .where('id', '=', disputeId)
      .executeTakeFirst();

    expect(dispute?.status).toBe('resolved');
    expect(dispute?.resolution).toContain('Partial refund');
  });
});
