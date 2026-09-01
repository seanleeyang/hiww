import 'dotenv/config';
import fastify, { FastifyInstance } from 'fastify';
import { Kysely } from 'kysely';
import { createDatabase } from '@/db/connection';
import { registerAuthRoutes } from '@/modules/auth/routes';
import { registerAdminRoutes } from '@/modules/admin/routes';
import { registerAdminActionRoutes } from '@/modules/admin/actions';
import type { Database } from '@/types/database';

describe('admin action flow', () => {
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
      registerAdminRoutes(instance);
      registerAdminActionRoutes(instance);
    });

    await app.ready();

    const shopper = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: 'admin-action-shopper@example.com',
        full_name: 'Admin Action Shopper',
        user_type: 'shopper',
        password: 'SecurePass123!',
      },
    });

    const traveler = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: 'admin-action-traveler@example.com',
        full_name: 'Admin Action Traveler',
        user_type: 'traveler',
        password: 'SecurePass123!',
      },
    });

    const shopperId = shopper.json().data.userId;
    const travelerId = traveler.json().data.userId;

    await db
      .insertInto('orders')
      .values({
        id: '33333333-3333-4333-8333-333333333333',
        shopper_id: shopperId,
        traveler_id: travelerId,
        item_description: 'Admin action test item',
        quantity: 1,
        unit_price: '45.00',
        total_price: '45.00',
        fees: '0.00',
        status: 'confirmed',
        created_at: new Date(),
        updated_at: new Date(),
      })
      .execute();

    await db
      .insertInto('disputes')
      .values({
        id: '44444444-4444-4444-8444-444444444444',
        order_id: '33333333-3333-4333-8333-333333333333',
        initiator_id: shopperId,
        reason: 'Package arrived damaged and no refund was issued',
        status: 'open',
        created_at: new Date(),
        updated_at: new Date(),
      })
      .execute();
  });

  afterEach(async () => {
    await app.close();
    await db.destroy();
  });

  it('allows admins to resolve disputes, review KYC, and flag risky users', async () => {
    const user = await db
      .selectFrom('users')
      .selectAll()
      .where('email', '=', 'admin-action-shopper@example.com')
      .executeTakeFirst();

    const disputeResponse = await app.inject({
      method: 'POST',
      url: '/api/admin/disputes/44444444-4444-4444-8444-444444444444/resolve',
      payload: {
        status: 'resolved',
        resolution: 'Refund approved after packaging inspection resulted in damage',
      },
    });

    expect(disputeResponse.statusCode).toBe(200);
    expect(disputeResponse.json().success).toBe(true);

    const kycResponse = await app.inject({
      method: 'POST',
      url: `/api/admin/users/${user!.id}/kyc-review`,
      payload: {
        status: 'approved',
        note: 'Documents verified successfully',
      },
    });

    expect(kycResponse.statusCode).toBe(200);
    expect(kycResponse.json().success).toBe(true);

    const flagResponse = await app.inject({
      method: 'POST',
      url: `/api/admin/users/${user!.id}/flag`,
      payload: {
        risk_status: 'flagged',
        reason: 'Repeated refund requests',
      },
    });

    expect(flagResponse.statusCode).toBe(200);
    expect(flagResponse.json().success).toBe(true);

    const updatedUser = await db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', user!.id)
      .executeTakeFirst();

    expect(updatedUser?.kyc_status).toBe('approved');
    expect(updatedUser?.risk_status).toBe('flagged');
  });
});
