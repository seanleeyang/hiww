import 'dotenv/config';
import fastify, { FastifyInstance } from 'fastify';
import { Kysely } from 'kysely';
import { createDatabase } from '@/db/connection';
import { registerTripsRoutes } from '@/modules/trips/routes';
import { registerAuthRoutes } from '@/modules/auth/routes';
import type { Database } from '@/types/database';

describe('auth and protected route flow', () => {
  let app: ReturnType<typeof fastify>;
  let db: Kysely<Database>;

  beforeEach(async () => {
    db = createDatabase();
    app = fastify();

    app.addHook('preHandler', async (request: any) => {
      request.db = db;

      const authHeader = request.headers.authorization;
      if (typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
        const token = authHeader.slice(7);
        const { verifyToken } = await import('@/utils/auth');
        const payload = verifyToken(token);
        request.userId = payload.userId;
        return;
      }

      request.userId = request.headers['x-user-id'] as string;
    });

    await app.register(async (instance: FastifyInstance) => {
      registerAuthRoutes(instance);
      registerTripsRoutes(instance);
    });

    await app.ready();
  });

  afterEach(async () => {
    await app.close();
    await db.destroy();
  });

  it('registers a user and allows a bearer token to create a trip', async () => {
    const registerResponse = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: 'alice@example.com',
        full_name: 'Alice Traveler',
        user_type: 'traveler',
        password: 'SecurePass123!',
      },
    });

    expect(registerResponse.statusCode).toBe(201);

    const registerBody = registerResponse.json();
    expect(registerBody.success).toBe(true);
    expect(registerBody.data.token).toBeTruthy();

    const token = registerBody.data.token as string;

    const tripResponse = await app.inject({
      method: 'POST',
      url: '/api/trips',
      headers: { authorization: `Bearer ${token}` },
      payload: {
        departure_country: 'US',
        arrival_country: 'FR',
        departure_date: '2026-10-15T08:00:00.000Z',
        return_date: '2026-10-22T08:00:00.000Z',
        max_weight_kg: 25,
        max_items: 3,
      },
    });

    expect(tripResponse.statusCode).toBe(201);

    const user = await db
      .selectFrom('users')
      .selectAll()
      .where('email', '=', 'alice@example.com')
      .executeTakeFirst();

    expect(user).toBeTruthy();
    expect(user?.full_name).toBe('Alice Traveler');
  });
});
