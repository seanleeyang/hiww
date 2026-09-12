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
  app.get('/api/ops/overview', async (request, reply) => {
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
      throw new AppError('DB_ERROR', 500, 'ops.dbErrorOverview');
    }
  });

  // Money reconciliation for the manual-money pilot: what is owed in, what is
  // owed out, and what has settled. Admin-only (auth guard).
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.get('/api/ops/reconciliation', async (request, reply) => {
    try {
      const awaitingPayment = await request.db
        .selectFrom('orders')
        .select([
          'id',
          'item_description',
          'total_price',
          'fees',
          'shopper_total',
          'shopper_id',
          'traveler_id',
          'payment_claimed_at',
          'created_at',
        ])
        .where('status', '=', 'pending_payment')
        .orderBy('created_at', 'asc')
        .execute();

      // Delivered orders with no payout row yet — the operator still owes the
      // traveller. Joins the traveller's own bank details (migration 042) so
      // the admin console can show — read-only — exactly where the payout
      // will go; the payout endpoint itself re-reads these server-side
      // rather than trusting anything from the client.
      const awaitingPayout = await request.db
        .selectFrom('orders')
        .leftJoin('payouts', 'payouts.order_id', 'orders.id')
        .innerJoin('users as traveler', 'traveler.id', 'orders.traveler_id')
        .select([
          'orders.id as id',
          'orders.item_description as item_description',
          'orders.total_price as total_price',
          'orders.fees as fees',
          'orders.traveller_payout as traveller_payout',
          'orders.traveler_id as traveler_id',
          'orders.delivered_at as delivered_at',
          'traveler.full_name as traveler_name',
          'traveler.bank_name as bank_name',
          'traveler.bank_account_number as bank_account_number',
        ])
        .where('orders.status', '=', 'delivered')
        .where('payouts.id', 'is', null)
        .orderBy('orders.delivered_at', 'asc')
        .execute();

      // Cancelled orders that had confirmed payment and no refund row yet —
      // the operator still owes the shopper money back (see
      // POST /api/admin/orders/:id/cancel's refund_due notification).
      const awaitingRefund = await request.db
        .selectFrom('orders')
        .leftJoin('refunds', 'refunds.order_id', 'orders.id')
        .select([
          'orders.id as id',
          'orders.item_description as item_description',
          'orders.total_price as total_price',
          'orders.fees as fees',
          'orders.shopper_total as shopper_total',
          'orders.shopper_id as shopper_id',
          'orders.cancelled_at as cancelled_at',
        ])
        .where('orders.status', '=', 'cancelled')
        .where('orders.confirmed_at', 'is not', null)
        .where('refunds.id', 'is', null)
        .orderBy('orders.cancelled_at', 'asc')
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
          'payouts.bank_name as bank_name',
          'payouts.bank_account_number as bank_account_number',
          'orders.item_description as item_description',
        ])
        .orderBy('payouts.created_at', 'desc')
        .limit(100)
        .execute();

      const refunded = await request.db
        .selectFrom('refunds')
        .innerJoin('orders', 'orders.id', 'refunds.order_id')
        .select([
          'refunds.id as id',
          'refunds.order_id as order_id',
          'refunds.amount as amount',
          'refunds.method as method',
          'refunds.reference as reference',
          'refunds.recorded_by as recorded_by',
          'refunds.created_at as created_at',
          'orders.item_description as item_description',
        ])
        .orderBy('refunds.created_at', 'desc')
        .limit(100)
        .execute();

      reply.send({
        success: true,
        data: {
          awaiting_payment: {
            count: awaitingPayment.length,
            // What the shoppers still owe. Prefers the stored pricing-model
            // snapshot (item + reward + fee); falls back to goods price +
            // fee for orders created before that snapshot existed.
            total: awaitingPayment
              .reduce(
                (a: Decimal, r: any) =>
                  a.add(new Decimal(r.shopper_total ?? new Decimal(r.total_price).add(r.fees))),
                new Decimal(0)
              )
              .toFixed(2),
            claimed: awaitingPayment.filter((o: any) => o.payment_claimed_at).length,
            orders: awaitingPayment,
          },
          awaiting_payout: {
            count: awaitingPayout.length,
            // What the operator owes travellers: goods price + reward under
            // the pricing model, falling back to goods price only for
            // orders created before the reward concept existed.
            total: awaitingPayout
              .reduce((a: Decimal, r: any) => a.add(new Decimal(r.traveller_payout ?? r.total_price)), new Decimal(0))
              .toFixed(2),
            orders: awaitingPayout,
          },
          paid_out: {
            count: paidOut.length,
            total: sum(paidOut, 'amount'),
            payouts: paidOut,
          },
          awaiting_refund: {
            count: awaitingRefund.length,
            total: awaitingRefund
              .reduce(
                (a: Decimal, r: any) =>
                  a.add(new Decimal(r.shopper_total ?? new Decimal(r.total_price).add(r.fees))),
                new Decimal(0)
              )
              .toFixed(2),
            orders: awaitingRefund,
          },
          refunded: {
            count: refunded.length,
            total: sum(refunded, 'amount'),
            refunds: refunded,
          },
        },
        code: 'OPS_RECONCILIATION',
      });
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw new AppError('DB_ERROR', 500, 'ops.dbErrorReconciliation');
    }
  });
}
