import 'dotenv/config';
import { randomUUID } from 'crypto';
import fastify, { FastifyInstance } from 'fastify';
import { Kysely } from 'kysely';
import { createDatabase } from '@/db/connection';
import { registerMoneyRoutes } from '@/modules/money/routes';
import type { Database } from '@/types/database';

describe('payment confirmation flow', () => {
  let app: ReturnType<typeof fastify>;
  let db: Kysely<Database>;
  let travelerId: string;
  let shopperId: string;
  let orderId: string;

  beforeEach(async () => {
    travelerId = randomUUID();
    shopperId = randomUUID();
    orderId = randomUUID();

    db = createDatabase();
    app = fastify();

    app.addHook('preHandler', async (request: any) => {
      request.db = db;
      request.userId = 'user-123';
    });

    await app.register(async (instance: FastifyInstance) => {
      registerMoneyRoutes(instance);
    });

    await app.ready();

    await db
      .insertInto('users')
      .values({
        id: travelerId,
        email: `${randomUUID()}@example.com`,
        full_name: 'Traveler One',
        user_type: 'traveler',
        kyc_status: 'approved',
        created_at: new Date(),
        updated_at: new Date(),
      })
      .execute();

    await db
      .insertInto('users')
      .values({
        id: shopperId,
        email: `${randomUUID()}@example.com`,
        full_name: 'Shopper One',
        user_type: 'shopper',
        kyc_status: 'approved',
        created_at: new Date(),
        updated_at: new Date(),
      })
      .execute();

    await db
      .insertInto('orders')
      .values({
        id: orderId,
        shopper_id: shopperId,
        traveler_id: travelerId,
        item_description: 'Test item',
        quantity: 2,
        unit_price: '75.00',
        total_price: '162.00',
        fees: '12.00',
        status: 'pending_payment',
        created_at: new Date(),
        updated_at: new Date(),
      })
      .execute();
  });

  afterEach(async () => {
    await app.close();
    await db.destroy();
  });

  it('updates the order and creates ledger entries when payment is confirmed', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/payments/confirm',
      payload: {
        payment_id: `payment_${orderId}`,
        order_id: orderId,
      },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      success: true,
      data: {
        status: 'confirmed',
        order_id: orderId,
      },
    });

    const order = await db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', orderId)
      .executeTakeFirst();

    expect(order?.status).toBe('confirmed');

    const ledgerEntries = await db
      .selectFrom('ledger_entries')
      .selectAll()
      .where('order_id', '=', orderId)
      .orderBy('created_at', 'asc')
      .execute();

    expect(ledgerEntries).toHaveLength(2);
    expect(ledgerEntries.map((entry) => entry.user_id).sort()).toEqual([travelerId, shopperId].sort());
  });
});
