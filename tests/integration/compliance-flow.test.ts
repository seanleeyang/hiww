import 'dotenv/config';
import fastify, { FastifyInstance } from 'fastify';
import { Kysely } from 'kysely';
import { createDatabase } from '@/db/connection';
import { registerAuthRoutes } from '@/modules/auth/routes';
import { registerComplianceRoutes } from '@/modules/compliance/routes';
import type { Database } from '@/types/database';

describe('compliance flow', () => {
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
    });

    await app.ready();

    const register = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: 'kyc-user@example.com',
        full_name: 'KYC User',
        user_type: 'traveler',
        password: 'SecurePass123!',
      },
    });

    const token = register.json().data.token;

    await app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/submit',
      headers: { authorization: `Bearer ${token}` },
      payload: {
        document_type: 'passport',
        document_id: 'ABC12345',
      },
    });
  });

  afterEach(async () => {
    await app.close();
    await db.destroy();
  });

  it('reviews and approves a user KYC record', async () => {
    const user = await db
      .selectFrom('users')
      .selectAll()
      .where('email', '=', 'kyc-user@example.com')
      .executeTakeFirst();

    const approveResponse = await app.inject({
      method: 'POST',
      url: '/api/compliance/kyc/approve',
      payload: {
        user_id: user!.id,
        status: 'approved',
      },
    });

    expect(approveResponse.statusCode).toBe(200);
    expect(approveResponse.json().success).toBe(true);

    const updatedUser = await db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', user!.id)
      .executeTakeFirst();

    expect(updatedUser?.kyc_status).toBe('approved');
  });
});
