import { FastifyInstance } from 'fastify';
import Decimal from 'decimal.js';
import { AppError, generateId } from '@/utils/helpers';
import { getPaymentProvider } from '@/services/providers';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerMoneyRoutes(app: FastifyInstance): Promise<void> {
  app.get<{ Params: { userId: string } }>(
    '/api/ledger/:userId',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const entries = await request.db
        .selectFrom('ledger_entries')
        .selectAll()
        .where('user_id', '=', request.params.userId)
        .orderBy('created_at', 'desc')
        .execute();

      if (entries.length === 0) {
        reply.send({ success: true, data: { entries: [], balance: '0' }, code: 'LEDGER_FOUND' });
        return;
      }

      const lastEntry = entries[0];
      const balance = lastEntry.balance_after;

      reply.send({
        success: true,
        data: {
          entries,
          balance,
          user_id: request.params.userId,
        },
        code: 'LEDGER_FOUND',
      });
    }
  );

  app.post<{ Body: unknown }>(
    '/api/payments/initiate',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const body = request.body as { order_id: string };
      if (!body.order_id) {
        throw new AppError('VALIDATION_ERROR', 400, 'order_id is required');
      }

      // Verify order exists
      const order = await request.db
        .selectFrom('orders')
        .select('id')
        .where('id', '=', body.order_id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'Order not found');
      }

      const paymentProvider = getPaymentProvider();
      const session = await paymentProvider.createSession({
        id: order.id,
        total_price: order.total_price,
        shopper_id: order.shopper_id,
        traveler_id: order.traveler_id,
        item_description: order.item_description,
      });

      reply.status(202).send({
        success: true,
        data: session,
        code: 'PAYMENT_INITIATED',
      });
    }
  );

  app.post<{ Body: unknown }>(
    '/api/payments/confirm',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const body = request.body as { payment_id: string; order_id: string };
      if (!body.payment_id || !body.order_id) {
        throw new AppError('VALIDATION_ERROR', 400, 'payment_id and order_id required');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', body.order_id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'Order not found');
      }

      const total = new Decimal(order.total_price);
      const now = new Date();

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await request.db.transaction().execute(async (trx: any) => {
        await trx
          .updateTable('orders')
          .set({ status: 'confirmed', updated_at: now })
          .where('id', '=', order.id)
          .execute();

        const shopperBalanceEntry = await trx
          .selectFrom('ledger_entries')
          .select('balance_after')
          .where('user_id', '=', order.shopper_id)
          .orderBy('created_at', 'desc')
          .limit(1)
          .executeTakeFirst();

        const shopperBalance = shopperBalanceEntry
          ? new Decimal(shopperBalanceEntry.balance_after)
          : new Decimal(0);

        const travelerBalanceEntry = await trx
          .selectFrom('ledger_entries')
          .select('balance_after')
          .where('user_id', '=', order.traveler_id)
          .orderBy('created_at', 'desc')
          .limit(1)
          .executeTakeFirst();

        const travelerBalance = travelerBalanceEntry
          ? new Decimal(travelerBalanceEntry.balance_after)
          : new Decimal(0);

        await trx
          .insertInto('ledger_entries')
          .values({
            id: generateId(),
            user_id: order.shopper_id,
            order_id: order.id,
            entry_type: 'debit',
            amount: total.neg().toString(),
            balance_after: shopperBalance.minus(total).toString(),
            description: `Payment confirmed for order ${order.id}`,
            created_at: now,
          })
          .execute();

        await trx
          .insertInto('ledger_entries')
          .values({
            id: generateId(),
            user_id: order.traveler_id,
            order_id: order.id,
            entry_type: 'credit',
            amount: total.toString(),
            balance_after: travelerBalance.plus(total).toString(),
            description: `Funds released for order ${order.id}`,
            created_at: now,
          })
          .execute();
      });

      reply.send({
        success: true,
        data: { status: 'confirmed', order_id: body.order_id },
        code: 'PAYMENT_CONFIRMED',
      });
    }
  );
}
