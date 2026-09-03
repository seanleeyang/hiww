import { FastifyInstance } from 'fastify';
import Decimal from 'decimal.js';
import { AppError } from '@/utils/helpers';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function sum(rows: any[], field: string): string {
  return rows.reduce((acc, r) => acc.add(new Decimal(r[field] ?? 0)), new Decimal(0)).toFixed(2);
}

async function countTable(request: any, tableName: string): Promise<number> {
  const result = await request.db
    .selectFrom(tableName)
    .select((db: any) => [db.fn.count('id').as('count')])
    .executeTakeFirst();

  return Number(result?.count ?? 0);
}

async function countByStatus(request: any, tableName: string, fieldName: string, status: string): Promise<number> {
  const result = await request.db
    .selectFrom(tableName)
    .select((db: any) => [db.fn.count('id').as('count')])
    .where(fieldName, '=', status)
    .executeTakeFirst();

  return Number(result?.count ?? 0);
}

async function countUsersByType(request: any, userType: 'shopper' | 'traveler' | 'both'): Promise<number> {
  const result = await request.db
    .selectFrom('users')
    .select((db: any) => [db.fn.count('id').as('count')])
    .where('user_type', '=', userType)
    .executeTakeFirst();

  return Number(result?.count ?? 0);
}

export async function registerOpsRoutes(app: FastifyInstance): Promise<void> {
  app.get('/api/ops/overview', async (request: any, reply: any) => {
    try {
      const [users, shoppers, travelers, trips, requests, orders, openRequests, publishedTrips, pendingOrders] = await Promise.all([
        countTable(request, 'users'),
        countUsersByType(request, 'shopper'),
        countUsersByType(request, 'traveler'),
        countTable(request, 'trips'),
        countTable(request, 'requests'),
        countTable(request, 'orders'),
        countByStatus(request, 'requests', 'status', 'open'),
        countByStatus(request, 'trips', 'status', 'published'),
        countByStatus(request, 'orders', 'status', 'pending_payment'),
      ]);

      reply.send({
        success: true,
        data: {
          users,
          shoppers,
          travelers,
          trips,
          requests,
          orders,
          open_requests: openRequests,
          published_trips: publishedTrips,
          pending_orders: pendingOrders,
        },
        code: 'OPS_OVERVIEW',
      });
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw new AppError('DB_ERROR', 500, 'Failed to load ops overview');
    }
  });

  // Money reconciliation for the manual-money pilot: what is owed in, what is
  // owed out, and what has settled. Admin-only (auth guard).
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.get('/api/ops/reconciliation', async (request: any, reply: any) => {
    try {
      const awaitingPayment = await request.db
        .selectFrom('orders')
        .select(['id', 'item_description', 'total_price', 'fees', 'shopper_id', 'traveler_id', 'payment_claimed_at', 'created_at'])
        .where('status', '=', 'pending_payment')
        .orderBy('created_at', 'asc')
        .execute();

      // Delivered orders with no payout row yet — the operator still owes the traveller.
      const awaitingPayout = await request.db
        .selectFrom('orders')
        .leftJoin('payouts', 'payouts.order_id', 'orders.id')
        .select([
          'orders.id as id',
          'orders.item_description as item_description',
          'orders.total_price as total_price',
          'orders.fees as fees',
          'orders.traveler_id as traveler_id',
          'orders.delivered_at as delivered_at',
        ])
        .where('orders.status', '=', 'delivered')
        .where('payouts.id', 'is', null)
        .orderBy('orders.delivered_at', 'asc')
        .execute();

      const paidOut = await request.db
        .selectFrom('payouts')
        .innerJoin('orders', 'orders.id', 'payouts.order_id')
        .select([
          'payouts.id as id',
          'payouts.order_id as order_id',
          'payouts.amount as amount',
          'payouts.method as method',
          'payouts.reference as reference',
          'payouts.recorded_by as recorded_by',
          'payouts.created_at as created_at',
          'orders.item_description as item_description',
        ])
        .orderBy('payouts.created_at', 'desc')
        .limit(100)
        .execute();

      reply.send({
        success: true,
        data: {
          awaiting_payment: {
            count: awaitingPayment.length,
            // What the shoppers still owe: goods price + fee.
            total: awaitingPayment
              .reduce((a: Decimal, r: any) => a.add(new Decimal(r.total_price)).add(new Decimal(r.fees)), new Decimal(0))
              .toFixed(2),
            claimed: awaitingPayment.filter((o: any) => o.payment_claimed_at).length,
            orders: awaitingPayment,
          },
          awaiting_payout: {
            count: awaitingPayout.length,
            // What the operator owes travellers: the goods price only.
            total: sum(awaitingPayout, 'total_price'),
            orders: awaitingPayout,
          },
          paid_out: {
            count: paidOut.length,
            total: sum(paidOut, 'amount'),
            payouts: paidOut,
          },
        },
        code: 'OPS_RECONCILIATION',
      });
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw new AppError('DB_ERROR', 500, 'Failed to load reconciliation');
    }
  });
}
