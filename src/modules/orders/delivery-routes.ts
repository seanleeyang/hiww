import { FastifyInstance } from 'fastify';
import { sql } from 'kysely';
import { z } from 'zod';
import { AppError } from '@/utils/helpers';
import { purchaseProofSchema } from '@/types/schemas';
import { recordAudit, actorFromRequest } from '@/services/audit';
import { recordNotification, recordNotifications } from '@/services/notify';

const noteSchema = z.object({
  note: z.string().min(1).optional(),
});

/**
 * Delivery lifecycle.
 *
 * These endpoints only move the order status. During the manual-money pilot no
 * funds move here — an admin pays the traveler out-of-band once the order is
 * marked `delivered` and records it separately. The double-credit bug in the
 * original release handler (funds granted both here and at payment confirm) has
 * been removed along with the ledger writes.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerDeliveryRoutes(app: FastifyInstance): Promise<void> {
  // The traveler has bought the item and uploads a photo of the shop receipt.
  // `confirmed` → `purchased`. This is what unlocks "mark shipped" — the
  // traveler still has to carry the item home and post it, which takes time.
  app.post<{ Params: { id: string }; Body: unknown }>(
    '/api/orders/:id/purchase-proof',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = purchaseProofSchema.safeParse(request.body || {});
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'A receipt photo URL is required');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'Order not found');
      }
      if (order.traveler_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'Only the traveler can upload a purchase receipt');
      }
      if (order.status === 'purchased') {
        reply.send({ success: true, data: { order_id: order.id, status: 'purchased' }, code: 'PURCHASE_RECORDED' });
        return;
      }
      if (order.status !== 'confirmed') {
        throw new AppError('INVALID_STATUS', 409, 'Payment must be confirmed before recording a purchase');
      }

      const now = new Date();
      await request.db
        .updateTable('orders')
        .set({
          status: 'purchased',
          purchase_proof_url: parsed.data.image_url,
          purchased_at: now,
          updated_at: now,
        })
        .where('id', '=', order.id)
        .execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'order.purchase_proof',
        targetType: 'order',
        targetId: order.id,
        summary: `Traveler uploaded a purchase receipt for order ${order.id}`,
        metadata: {
          from_status: 'confirmed',
          to_status: 'purchased',
          receipt_url: parsed.data.image_url,
          note: parsed.data.note ?? null,
        },
      });

      await recordNotification(request.db, {
        userId: order.shopper_id,
        type: 'purchase_proof',
        subject: 'The traveler bought your item',
        body: `The traveler bought "${order.item_description}" and attached the shop receipt. They'll ship it once they're back.`,
        orderId: order.id,
      });

      reply.send({
        success: true,
        data: { order_id: order.id, status: 'purchased' },
        code: 'PURCHASE_RECORDED',
      });
    }
  );

  app.post<{ Params: { id: string }; Body: unknown }>(
    '/api/orders/:id/deliver',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = noteSchema.safeParse(request.body || {});
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Invalid delivery payload');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'Order not found');
      }

      if (order.traveler_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'Only the traveler can mark an order delivered');
      }

      if (order.status === 'in_transit') {
        reply.send({ success: true, data: { order_id: order.id, status: 'in_transit' }, code: 'ORDER_MARKED_DELIVERED' });
        return;
      }

      if (order.status !== 'purchased') {
        throw new AppError(
          'INVALID_STATUS',
          409,
          'Upload the purchase receipt before marking the order shipped'
        );
      }

      const now = new Date();
      await request.db
        .updateTable('orders')
        .set({ status: 'in_transit', shipped_at: now, updated_at: now })
        .where('id', '=', order.id)
        .execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'order.ship',
        targetType: 'order',
        targetId: order.id,
        summary: `Traveler marked order ${order.id} shipped`,
        metadata: { from_status: 'purchased', to_status: 'in_transit', note: parsed.data.note ?? null },
      });

      await recordNotification(request.db, {
        userId: order.shopper_id,
        type: 'shipped',
        subject: 'Your item is on the way',
        body: `The traveler marked "${order.item_description}" as shipped. Confirm receipt in the app once it arrives.`,
        orderId: order.id,
      });

      reply.send({
        success: true,
        data: { order_id: order.id, status: 'in_transit' },
        code: 'ORDER_MARKED_DELIVERED',
      });
    }
  );

  app.post<{ Params: { id: string }; Body: unknown }>(
    '/api/orders/:id/release',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = noteSchema.safeParse(request.body || {});
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Invalid release payload');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'Order not found');
      }

      if (order.shopper_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'Only the shopper can confirm receipt');
      }

      if (order.status === 'delivered') {
        reply.send({ success: true, data: { order_id: order.id, status: 'delivered' }, code: 'ORDER_RELEASED' });
        return;
      }

      if (order.status !== 'in_transit') {
        throw new AppError('INVALID_STATUS', 409, 'Order must be in transit before release');
      }

      const now = new Date();
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await request.db.transaction().execute(async (trx: any) => {
        await trx
          .updateTable('orders')
          .set({ status: 'delivered', delivered_at: now, updated_at: now })
          .where('id', '=', order.id)
          .execute();
        await trx
          .updateTable('users')
          .set({ delivered_count: sql`delivered_count + 1`, updated_at: now })
          .where('id', '=', order.traveler_id)
          .execute();
        await recordAudit(trx, actorFromRequest(request), {
          action: 'order.release',
          targetType: 'order',
          targetId: order.id,
          summary: `Shopper confirmed receipt of order ${order.id} — payout to traveler is now due`,
          metadata: {
            from_status: 'in_transit',
            to_status: 'delivered',
            total_price: order.total_price,
            shopper_id: order.shopper_id,
            traveler_id: order.traveler_id,
            note: parsed.data.note ?? null,
          },
        });
        await recordNotifications(trx, [
          {
            userId: order.traveler_id,
            type: 'delivered',
            subject: 'Order complete — payout on the way',
            body: `The shopper confirmed they received "${order.item_description}". Hiww will send your payout shortly.`,
            orderId: order.id,
          },
          {
            userId: order.shopper_id,
            type: 'delivered',
            subject: 'Order complete',
            body: `You confirmed receipt of "${order.item_description}". Tap to leave the traveler a review.`,
            orderId: order.id,
          },
        ]);
      });

      reply.send({
        success: true,
        data: { order_id: order.id, status: 'delivered' },
        code: 'ORDER_RELEASED',
      });
    }
  );
}
