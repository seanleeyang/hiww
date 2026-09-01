import 'dotenv/config';
import fastify, { FastifyInstance } from 'fastify';
import { Kysely } from 'kysely';
import { createDatabase } from '@/db/connection';
import { registerAuthRoutes } from '@/modules/auth/routes';
import { registerNotificationsRoutes } from '@/modules/notifications/routes';
import type { Database } from '@/types/database';

describe('notifications flow', () => {
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
      registerNotificationsRoutes(instance);
    });

    await app.ready();

    const register = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: 'notify-user@example.com',
        full_name: 'Notify User',
        user_type: 'shopper',
        password: 'SecurePass123!',
      },
    });

    token = register.json().data.token;

    await app.inject({
      method: 'POST',
      url: '/api/notifications',
      headers: { authorization: `Bearer ${token}` },
      payload: {
        type: 'email',
        subject: 'Order confirmed',
        body: 'Your order has been confirmed.',
      },
    });
  });

  afterEach(async () => {
    await app.close();
    await db.destroy();
  });

  it('creates and lists notifications for a user', async () => {
    const user = await db
      .selectFrom('users')
      .selectAll()
      .where('email', '=', 'notify-user@example.com')
      .executeTakeFirst();

    const listResponse = await app.inject({
      method: 'GET',
      url: `/api/notifications/${user!.id}`,
      headers: { authorization: `Bearer ${token}` },
    });

    expect(listResponse.statusCode).toBe(200);
    expect(listResponse.json().data.length).toBeGreaterThanOrEqual(1);
  });
});
