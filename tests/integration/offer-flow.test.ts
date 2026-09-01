import 'dotenv/config';
import fastify, { FastifyInstance } from 'fastify';
import { Kysely } from 'kysely';
import { createDatabase } from '@/db/connection';
import { registerAuthRoutes } from '@/modules/auth/routes';
import { registerOffersRoutes } from '@/modules/offers/routes';
import { registerRequestsRoutes } from '@/modules/requests/routes';
import { registerTripsRoutes } from '@/modules/trips/routes';
import type { Database } from '@/types/database';

describe('offer flow', () => {
  let app: ReturnType<typeof fastify>;
  let db: Kysely<Database>;
  let travelerToken: string;
  let shopperToken: string;

  beforeEach(async () => {
    db = createDatabase();
    app = fastify();

    app.addHook('preHandler', async (request: any) => {
      request.db = db;
      const authHeader = request.headers.authorization;
      if (typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
        const { verifyToken } = await import('@/utils/auth');
        const payload = verifyToken(authHeader.slice(7));
        request.userId = payload.userId;
      } else {
        request.userId = request.headers['x-user-id'] as string;
      }
    });

    await app.register(async (instance: FastifyInstance) => {
      registerAuthRoutes(instance);
      registerRequestsRoutes(instance);
      registerTripsRoutes(instance);
      registerOffersRoutes(instance);
    });

    await app.ready();

    const travelerRegister = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: 'traveler-offer@example.com',
        full_name: 'Traveler Offer',
        user_type: 'traveler',
        password: 'SecurePass123!',
      },
    });

    const shopperRegister = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: 'shopper-offer@example.com',
        full_name: 'Shopper Offer',
        user_type: 'shopper',
        password: 'SecurePass123!',
      },
    });

    travelerToken = travelerRegister.json().data.token;
    shopperToken = shopperRegister.json().data.token;

    await app.inject({
      method: 'POST',
      url: '/api/requests',
      headers: { authorization: `Bearer ${shopperToken}` },
      payload: {
        item_description: 'Luxury skincare set for gifting',
        source_country: 'US',
        category: 'beauty',
        estimated_weight_kg: 2,
        budget: '150.00',
      },
    });

    const requestId = (await db.selectFrom('requests').select('id').limit(1).executeTakeFirst())?.id;

    await app.inject({
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

    const tripId = (await db.selectFrom('trips').select('id').limit(1).executeTakeFirst())?.id;

    await db.updateTable('requests').set({ status: 'open' }).where('id', '=', requestId!).execute();
    await db.updateTable('trips').set({ status: 'published' }).where('id', '=', tripId!).execute();
  });

  afterEach(async () => {
    await app.close();
    await db.destroy();
  });

  it('creates an offer and accepts it into an order', async () => {
    const requestRow = await db.selectFrom('requests').selectAll().limit(1).executeTakeFirst();
    const tripRow = await db.selectFrom('trips').selectAll().limit(1).executeTakeFirst();

    const offerResponse = await app.inject({
      method: 'POST',
      url: '/api/offers',
      headers: { authorization: `Bearer ${travelerToken}` },
      payload: {
        request_id: requestRow!.id,
        quoted_price: '120.00',
        delivery_date: '2026-11-18T10:00:00.000Z',
      },
    });

    expect(offerResponse.statusCode).toBe(201);

    const offerId = offerResponse.json().data.id;

    const acceptedOfferResponse = await app.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/accept`,
      headers: { authorization: `Bearer ${shopperToken}` },
      payload: {
        trip_id: tripRow!.id,
        item_description: 'Luxury skincare set for gifting',
        quantity: 1,
        unit_price: '120.00',
      },
    });

    expect(acceptedOfferResponse.statusCode).toBe(200);
    expect(acceptedOfferResponse.json().success).toBe(true);

    const acceptedOffer = await db
      .selectFrom('offers')
      .selectAll()
      .where('id', '=', offerId)
      .executeTakeFirst();

    expect(acceptedOffer?.status).toBe('accepted');

    const order = await db
      .selectFrom('orders')
      .selectAll()
      .where('request_id', '=', requestRow!.id)
      .executeTakeFirst();

    expect(order).toBeTruthy();
    expect(order?.trip_id).toBe(tripRow!.id);
    expect(order?.status).toBe('pending_payment');
  });
});
