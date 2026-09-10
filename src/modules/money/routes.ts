import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';
import { getPaymentProvider } from '@/services/providers';
import { config } from '@/config/env';
import { recordAudit, actorFromRequest } from '@/services/audit';
import { recordNotification, recordNotifications } from '@/services/notify';
import { expireOverduePayments } from '@/services/order-expiry';

// Tight per-IP ceiling on money movement (defaults to 30/min).
const moneyRoute = {
  config: { rateLimit: { max: config.moneyRateLimitMax, timeWindow: config.rateLimitWindow } },
};

// `amount` is deliberately not accepted from the client — the payout amount
// is always derived server-side from the order's own stored pricing
// snapshot (`order.traveller_payout`), never trusted from the request body.
const payoutSchema = z.object({
  order_id: z.string().uuid(),
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
    async (request, reply) => {
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
    async (request, reply) => {
      const body = request.body as { order_id?: string };
      if (!body.order_id) {
        throw new AppError('VALIDATION_ERROR', 400, 'common.orderIdRequired');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', body.order_id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'common.orderNotFound');
      }

      const paymentProvider = getPaymentProvider();
      const session = await paymentProvider.createSession({
        id: order.id,
        total_price: order.shopper_total ?? order.total_price,
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
    async (request, reply) => {
      const body = request.body as { order_id?: string; payment_id?: string };
      if (!body.order_id) {
        throw new AppError('VALIDATION_ERROR', 400, 'common.orderIdRequired');
      }

      await expireOverduePayments(request.db);

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', body.order_id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'common.orderNotFound');
      }

      // Idempotent: only the first confirm transitions the order. Repeats are a
      // no-op that report the current state rather than moving money twice.
      // `already_confirmed` is only true if the order genuinely was confirmed
      // at some point — an order that expired unpaid and was auto-cancelled
      // (see expireOverduePayments above) never was, even though it's also
      // not `pending_payment` anymore.
      if (order.status !== 'pending_payment') {
        reply.send({
          success: true,
          data: { status: order.status, order_id: order.id, already_confirmed: order.status !== 'cancelled' },
          code: 'PAYMENT_ALREADY_RECORDED',
        });
        return;
      }

      if (!config.manualMoneyPilot) {
        // Placeholder for the future automated path: verify with the provider,
        // hold funds in escrow, write double-entry ledger rows.
        throw new AppError('NOT_IMPLEMENTED', 501, 'money.notImplemented');
      }

      const now = new Date();
      // Guarded by prior status so two concurrent confirms can't both fall
      // through and both transition — the loser gets zero rows back and
      // no-ops (the order really is confirmed by the time it replies, just
      // not by this particular call).
      const confirmed = await request.db
        .updateTable('orders')
        .set({ status: 'confirmed', confirmed_at: now, updated_at: now })
        .where('id', '=', order.id)
        .where('status', '=', 'pending_payment')
        .returning('id')
        .execute();
      if (confirmed.length === 0) {
        reply.send({
          success: true,
          data: { status: 'confirmed', order_id: order.id, already_confirmed: true },
          code: 'PAYMENT_ALREADY_RECORDED',
        });
        return;
      }

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
          params: { _variant: 'shopper', item: order.item_description },
          orderId: order.id,
        },
        {
          userId: order.traveler_id,
          type: 'payment_confirmed',
          params: { _variant: 'traveler', item: order.item_description },
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
    async (request, reply) => {
      const parsed = payoutSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'money.invalidPayoutPayload');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', parsed.data.order_id)
        .executeTakeFirst();
      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'common.orderNotFound');
      }
      if (order.status !== 'delivered') {
        throw new AppError('INVALID_STATUS', 409, 'money.onlyDeliveredCanPayout');
      }

      // A dispute can be opened any time, independent of order status —
      // including after release but before payout. Don't let money go out
      // the door while one is still unresolved.
      const openDispute = await request.db
        .selectFrom('disputes')
        .select('id')
        .where('order_id', '=', order.id)
        .where('status', 'in', ['open', 'in_review'])
        .executeTakeFirst();
      if (openDispute) {
        throw new AppError('INVALID_STATUS', 409, 'delivery.orderHasOpenDispute');
      }

      const existing = await request.db
        .selectFrom('payouts')
        .select(['id'])
        .where('order_id', '=', order.id)
        .executeTakeFirst();
      if (existing) {
        throw new AppError('ALREADY_DONE', 409, 'money.alreadyPaidOut');
      }

      // Server-authoritative: never trust a client-sent amount. Orders
      // created before the pricing-breakdown migration have no
      // traveller_payout snapshot, so fall back to the legacy convention
      // (payout = goods price only, per migrations/011_payouts.ts).
      const payoutAmount = order.traveller_payout ?? order.total_price;

      const payoutId = generateId();
      await request.db
        .insertInto('payouts')
        .values({
          id: payoutId,
          order_id: order.id,
          recorded_by: request.userId ?? null,
          amount: payoutAmount,
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
        summary: `Payout of ${payoutAmount} to traveler for order ${order.id} via ${parsed.data.method} (${parsed.data.reference})`,
        metadata: {
          payout_id: payoutId,
          amount: payoutAmount,
          method: parsed.data.method,
          reference: parsed.data.reference,
          order_total_price: order.total_price,
          traveler_id: order.traveler_id,
        },
      });

      await recordNotification(request.db, {
        userId: order.traveler_id,
        type: 'payout_sent',
        params: {
          amount: payoutAmount,
          item: order.item_description,
          method: parsed.data.method,
          reference: parsed.data.reference,
        },
        orderId: order.id,
      });

      reply.status(201).send({
        success: true,
        data: { id: payoutId, order_id: order.id, amount: payoutAmount },
        code: 'PAYOUT_RECORDED',
      });
    }
  );
}
