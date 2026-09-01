import { FastifyInstance } from 'fastify';
import { AppError } from '@/utils/helpers';
import { getPaymentProvider } from '@/services/providers';
import { config } from '@/config/env';

/**
 * Money endpoints.
 *
 * During the manual-money pilot (`config.manualMoneyPilot`) the platform never
 * moves funds on its own. An admin settles money out-of-band and then records
 * the state change here. All of these routes are admin-only (enforced by the
 * auth guard) and none of them write ledger entries — balances are not a
 * meaningful concept until a real payment provider and a double-entry ledger
 * are in place.
 */
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

      const balance = entries.length > 0 ? entries[0].balance_after : '0';

      reply.send({
        success: true,
        data: { entries, balance, user_id: request.params.userId },
        code: 'LEDGER_FOUND',
      });
    }
  );

  app.post<{ Body: unknown }>(
    '/api/payments/initiate',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const body = request.body as { order_id?: string };
      if (!body.order_id) {
        throw new AppError('VALIDATION_ERROR', 400, 'order_id is required');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
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

      reply.status(202).send({ success: true, data: session, code: 'PAYMENT_INITIATED' });
    }
  );

  app.post<{ Body: unknown }>(
    '/api/payments/confirm',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const body = request.body as { order_id?: string; payment_id?: string };
      if (!body.order_id) {
        throw new AppError('VALIDATION_ERROR', 400, 'order_id is required');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', body.order_id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'Order not found');
      }

      // Idempotent: only the first confirm transitions the order. Repeats are a
      // no-op that report the current state rather than moving money twice.
      if (order.status !== 'pending_payment') {
        reply.send({
          success: true,
          data: { status: order.status, order_id: order.id, already_confirmed: order.status !== 'pending_payment' },
          code: 'PAYMENT_ALREADY_RECORDED',
        });
        return;
      }

      if (!config.manualMoneyPilot) {
        // Placeholder for the future automated path: verify with the provider,
        // hold funds in escrow, write double-entry ledger rows.
        throw new AppError('NOT_IMPLEMENTED', 501, 'Automated payment capture is not implemented yet');
      }

      await request.db
        .updateTable('orders')
        .set({ status: 'confirmed', updated_at: new Date() })
        .where('id', '=', order.id)
        .execute();

      reply.send({
        success: true,
        data: { status: 'confirmed', order_id: order.id, recorded_by: request.userId },
        code: 'PAYMENT_CONFIRMED',
      });
    }
  );
}
