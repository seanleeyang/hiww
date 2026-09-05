import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';
import { getPaymentProvider } from '@/services/providers';
import { config } from '@/config/env';
import { recordAudit, actorFromRequest } from '@/services/audit';
import { recordNotification, recordNotifications } from '@/services/notify';

// Tight per-IP ceiling on money movement (defaults to 30/min).
const moneyRoute = {
  config: { rateLimit: { max: config.moneyRateLimitMax, timeWindow: config.rateLimitWindow } },
};

const payoutSchema = z.object({
  order_id: z.string().uuid(),
  amount: z.string().regex(/^\d+(\.\d{2})?$/),
  method: z.string().min(2).max(40),
  reference: z.string().min(1).max(120),
  note: z.string().max(500).optional(),
});

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
    moneyRoute,
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
    moneyRoute,
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

      const now = new Date();
      await request.db
        .updateTable('orders')
        .set({ status: 'confirmed', confirmed_at: now, updated_at: now })
        .where('id', '=', order.id)
        .execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'payment.confirm',
        targetType: 'order',
        targetId: order.id,
        summary: `Payment confirmed for order ${order.id} (${order.total_price})`,
        metadata: {
          from_status: 'pending_payment',
          to_status: 'confirmed',
          total_price: order.total_price,
          payment_id: body.payment_id ?? null,
          shopper_id: order.shopper_id,
          traveler_id: order.traveler_id,
        },
      });

      await recordNotifications(request.db, [
        {
          userId: order.shopper_id,
          type: 'payment_confirmed',
          subject: 'Payment confirmed',
          body: `Your payment for "${order.item_description}" is confirmed. The traveler can buy and ship it now.`,
          orderId: order.id,
        },
        {
          userId: order.traveler_id,
          type: 'payment_confirmed',
          subject: 'Payment received — you can ship',
          body: `Hiww confirmed the shopper's payment for "${order.item_description}". Go ahead and buy the item, then mark it shipped.`,
          orderId: order.id,
        },
      ]);

      reply.send({
        success: true,
        data: { status: 'confirmed', order_id: order.id, recorded_by: request.userId },
        code: 'PAYMENT_CONFIRMED',
      });
    }
  );

  // Record that the operator has paid the traveller out of band. Admin-only.
  // Only a `delivered` order can be paid out, and only once.
  app.post<{ Body: unknown }>(
    '/api/payments/payout',
    moneyRoute,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = payoutSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Invalid payout payload');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', parsed.data.order_id)
        .executeTakeFirst();
      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'Order not found');
      }
      if (order.status !== 'delivered') {
        throw new AppError('INVALID_STATUS', 409, 'Only a delivered order can be paid out');
      }

      const existing = await request.db
        .selectFrom('payouts')
        .select(['id'])
        .where('order_id', '=', order.id)
        .executeTakeFirst();
      if (existing) {
        throw new AppError('ALREADY_DONE', 409, 'This order has already been paid out');
      }

      const payoutId = generateId();
      await request.db
        .insertInto('payouts')
        .values({
          id: payoutId,
          order_id: order.id,
          recorded_by: request.userId ?? null,
          amount: parsed.data.amount,
          method: parsed.data.method,
          reference: parsed.data.reference,
          note: parsed.data.note ?? null,
          created_at: new Date(),
        })
        .execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'order.payout',
        targetType: 'order',
        targetId: order.id,
        summary: `Payout of ${parsed.data.amount} to traveler for order ${order.id} via ${parsed.data.method} (${parsed.data.reference})`,
        metadata: {
          payout_id: payoutId,
          amount: parsed.data.amount,
          method: parsed.data.method,
          reference: parsed.data.reference,
          order_total_price: order.total_price,
          traveler_id: order.traveler_id,
        },
      });

      await recordNotification(request.db, {
        userId: order.traveler_id,
        type: 'payout_sent',
        subject: 'You’ve been paid',
        body: `Hiww sent your payout of ${parsed.data.amount} for "${order.item_description}" via ${parsed.data.method} (ref ${parsed.data.reference}).`,
        orderId: order.id,
      });

      reply.status(201).send({
        success: true,
        data: { id: payoutId, order_id: order.id, amount: parsed.data.amount },
        code: 'PAYOUT_RECORDED',
      });
    }
  );
}
