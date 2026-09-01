import 'dotenv/config';
import fastify, { FastifyInstance } from 'fastify';
import { Kysely } from 'kysely';
import { createDatabase } from '@/db/connection';
import { registerAuthRoutes } from '@/modules/auth/routes';
import { registerComplianceRoutes } from '@/modules/compliance/routes';
import { registerAdminRoutes } from '@/modules/admin/routes';
import type { Database } from '@/types/database';

describe('admin review flow', () => {
  let app: ReturnType<typeof fastify>;
  let db: Kysely<Database>;

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
      registerComplianceRoutes(instance);
      registerAdminRoutes(instance);
    });

    await app.ready();

    const shopper = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: 'admin-review-shopper@example.com',
        full_name: 'Admin Review Shopper',
        user_type: 'shopper',
        password: 'SecurePass123!',
      },
    });

    const traveler = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: 'admin-review-traveler@example.com',
        full_name: 'Admin Review Traveler',
        user_type: 'traveler',
        password: 'SecurePass123!',
      },
    });

    const shopperId = shopper.json().data.userId;
    const travelerId = traveler.json().data.userId;

    await db
      .insertInto('orders')
      .values({
        id: '11111111-1111-4111-8111-111111111111',
        shopper_id: shopperId,
        traveler_id: travelerId,
        item_description: 'Test item',
        quantity: 1,
        unit_price: '50.00',
        total_price: '50.00',
        fees: '0.00',
        status: 'confirmed',
        created_at: new Date(),
        updated_at: new Date(),
      })
      .execute();

    await db
      .insertInto('disputes')
      .values({
        id: '22222222-2222-4222-8222-222222222222',
        order_id: '11111111-1111-4111-8111-111111111111',
        initiator_id: shopperId,
        reason: 'Order arrived damaged and package did not match description',
        status: 'open',
        created_at: new Date(),
        updated_at: new Date(),
      })
      .execute();

    await db
      .updateTable('users')
      .set({ kyc_status: 'pending', updated_at: new Date() })
      .where('email', '=', 'admin-review-shopper@example.com')
      .execute();
  });

  afterEach(async () => {
    await app.close();
    await db.destroy();
  });

  it('returns a combined admin review queue with disputes and KYC cases', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/api/admin/reviews',
    });

    expect(response.statusCode).toBe(200);
    expect(response.json().success).toBe(true);
    expect(response.json().data.count).toBeGreaterThanOrEqual(2);
    expect(response.json().data.queue.some((item: any) => item.type === 'dispute')).toBe(true);
    expect(response.json().data.queue.some((item: any) => item.type === 'kyc')).toBe(true);
  });
});
