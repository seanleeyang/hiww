import 'dotenv/config';
import fastify, { FastifyInstance } from 'fastify';
import { Kysely } from 'kysely';
import { createDatabase } from '@/db/connection';
import { registerAuthRoutes } from '@/modules/auth/routes';
import { registerMoneyRoutes } from '@/modules/money/routes';
import { registerComplianceRoutes } from '@/modules/compliance/routes';
import { registerExternalRoutes } from '@/modules/external/routes';
import type { Database } from '@/types/database';

describe('external integrations flow', () => {
  let app: ReturnType<typeof fastify>;
  let db: Kysely<Database>;
  let token: string;

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
      registerMoneyRoutes(instance);
      registerComplianceRoutes(instance);
      registerExternalRoutes(instance);
    });

    await app.ready();

    const uniqueEmail = `external-user-${Date.now()}@example.com`;

    const register = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: uniqueEmail,
        full_name: 'External User',
        user_type: 'traveler',
        password: 'SecurePass123!',
      },
    });

    token = register.json().data.token;
  });

  afterEach(async () => {
    await app.close();
    await db.destroy();
  });

  it('creates a provider-backed payment session and verifies a KYC identity payload', async () => {
    const shopperId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    const travelerId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

    await db
      .insertInto('users')
      .values([
        {
          id: shopperId,
          email: 'external-shopper@example.com',
          full_name: 'External Shopper',
          user_type: 'shopper',
          kyc_status: 'approved',
          risk_status: 'clear',
          password_hash: 'hash',
          created_at: new Date(),
          updated_at: new Date(),
        },
        {
          id: travelerId,
          email: 'external-traveler@example.com',
          full_name: 'External Traveler',
          user_type: 'traveler',
          kyc_status: 'approved',
          risk_status: 'clear',
          password_hash: 'hash',
          created_at: new Date(),
          updated_at: new Date(),
        },
      ])
      .execute();

    await db
      .insertInto('orders')
      .values({
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        shopper_id: shopperId,
        traveler_id: travelerId,
        item_description: 'Integration test item',
        quantity: 1,
        unit_price: '40.00',
        total_price: '40.00',
        fees: '0.00',
        status: 'pending_payment',
        created_at: new Date(),
        updated_at: new Date(),
      })
      .execute();

    const paymentResponse = await app.inject({
      method: 'POST',
      url: '/api/payments/initiate',
      payload: { order_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' },
    });

    expect(paymentResponse.statusCode).toBe(202);
    expect(paymentResponse.json().data.provider).toBe('mock_payment_provider');
    expect(paymentResponse.json().data.payment_id).toContain('payment_');

    const verificationResponse = await app.inject({
      method: 'POST',
      url: '/api/identity/verify',
      headers: { authorization: `Bearer ${token}` },
      payload: {
        document_type: 'passport',
        document_id: 'ABC12345',
      },
    });

    expect(verificationResponse.statusCode).toBe(200);
    expect(verificationResponse.json().success).toBe(true);
    expect(verificationResponse.json().data.provider).toBe('mock_identity_provider');
    expect(verificationResponse.json().data.status).toBe('verified');
  });
});
