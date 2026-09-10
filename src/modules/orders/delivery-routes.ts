import { FastifyInstance } from 'fastify';
import { sql } from 'kysely';
import { z } from 'zod';
import { AppError } from '@/utils/helpers';
import { config } from '@/config/env';
import { purchaseProofSchema, shippingProofSchema, releaseSchema } from '@/types/schemas';
import { recordAudit, actorFromRequest } from '@/services/audit';
import { recordNotification, recordNotifications } from '@/services/notify';
import { runReceiptCheck } from '@/services/receipt-check';

const noteSchema = z.object({
  note: z.string().min(1).optional(),
  /** Optional shipping evidence — a photo with the courier or a screenshot
   * of the delivery app's booking page. Only meaningful on `/deliver`;
   * harmless if present but unused on `/release`. */
  shipping_proof_url: z.string().url().optional(),
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
        throw new AppError('VALIDATION_ERROR', 400, 'delivery.receiptUrlRequired');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'common.orderNotFound');
      }
      if (order.traveler_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'delivery.onlyTravelerCanUploadReceipt');
      }
      if (order.status === 'purchased') {
        reply.send({ success: true, data: { order_id: order.id, status: 'purchased' }, code: 'PURCHASE_RECORDED' });
        return;
      }
      if (order.status !== 'confirmed') {
        throw new AppError('INVALID_STATUS', 409, 'delivery.paymentMustBeConfirmed');
      }

      const now = new Date();
      await request.db
        .updateTable('orders')
        .set({
          status: 'purchased',
          purchase_proof_url: parsed.data.image_url,
          item_photo_url: parsed.data.item_photo_url ?? null,
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
          item_photo_url: parsed.data.item_photo_url ?? null,
          note: parsed.data.note ?? null,
        },
      });

      await recordNotification(request.db, {
        userId: order.shopper_id,
        type: 'purchase_proof',
        params: { item: order.item_description },
        orderId: order.id,
      });

      // AI receipt check. With the mock analyzer (tests, local) it's instant and
      // deterministic, so await it. With a real model it takes a few seconds —
      // don't make the traveller's request wait; it runs in the background and
      // the operator picks up any flag from the review queue.
      const check = runReceiptCheck(request.db, {
        ...order,
        purchase_proof_url: parsed.data.image_url,
        item_photo_url: parsed.data.item_photo_url ?? null,
      });
      if (config.aiReceiptAnalyzer === 'claude') {
        void check.catch(() => undefined);
      } else {
        await check;
      }

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
        throw new AppError('VALIDATION_ERROR', 400, 'delivery.invalidDeliveryPayload');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'common.orderNotFound');
      }

      if (order.traveler_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'delivery.onlyTravelerCanMarkDelivered');
      }

      if (order.status === 'in_transit') {
        reply.send({ success: true, data: { order_id: order.id, status: 'in_transit' }, code: 'ORDER_MARKED_DELIVERED' });
        return;
      }

      if (order.status !== 'purchased') {
        throw new AppError('INVALID_STATUS', 409, 'delivery.uploadReceiptFirst');
      }

      const now = new Date();
      await request.db
        .updateTable('orders')
        .set({
          status: 'in_transit',
          shipped_at: now,
          shipping_proof_url: parsed.data.shipping_proof_url ?? null,
          updated_at: now,
        })
        .where('id', '=', order.id)
        .execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'order.ship',
        targetType: 'order',
        targetId: order.id,
        summary: `Traveler marked order ${order.id} shipped`,
        metadata: {
          from_status: 'purchased',
          to_status: 'in_transit',
          note: parsed.data.note ?? null,
          shipping_proof_url: parsed.data.shipping_proof_url ?? null,
        },
      });

      await recordNotification(request.db, {
        userId: order.shopper_id,
        type: 'shipped',
        params: { item: order.item_description },
        orderId: order.id,
      });

      reply.send({
        success: true,
        data: { order_id: order.id, status: 'in_transit' },
        code: 'ORDER_MARKED_DELIVERED',
      });
    }
  );

  // Add or replace shipping proof after the fact — the picker on `/deliver`
  // is a one-shot opportunity (a traveler who skips it there has no way
  // back), so this lets them attach it any time while still in_transit,
  // not just at the moment they mark it shipped.
  app.post<{ Params: { id: string }; Body: unknown }>(
    '/api/orders/:id/shipping-proof',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = shippingProofSchema.safeParse(request.body || {});
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'delivery.shippingProofUrlRequired');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'common.orderNotFound');
      }
      if (order.traveler_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'delivery.onlyTravelerCanUploadShippingProof');
      }
      if (order.status !== 'in_transit') {
        throw new AppError('INVALID_STATUS', 409, 'delivery.mustBeInTransitToAddShippingProof');
      }

      await request.db
        .updateTable('orders')
        .set({ shipping_proof_url: parsed.data.image_url, updated_at: new Date() })
        .where('id', '=', order.id)
        .execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'order.shipping_proof',
        targetType: 'order',
        targetId: order.id,
        summary: `Traveler added shipping proof for order ${order.id}`,
        metadata: { shipping_proof_url: parsed.data.image_url },
      });

      reply.send({
        success: true,
        data: { order_id: order.id, shipping_proof_url: parsed.data.image_url },
        code: 'SHIPPING_PROOF_ADDED',
      });
    }
  );

  app.post<{ Params: { id: string }; Body: unknown }>(
    '/api/orders/:id/release',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = releaseSchema.safeParse(request.body || {});
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'delivery.invalidReleasePayload');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'common.orderNotFound');
      }

      if (order.shopper_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'delivery.onlyShopperCanConfirmReceipt');
      }

      if (order.status === 'delivered') {
        reply.send({ success: true, data: { order_id: order.id, status: 'delivered' }, code: 'ORDER_RELEASED' });
        return;
      }

      if (order.status !== 'in_transit') {
        throw new AppError('INVALID_STATUS', 409, 'delivery.mustBeInTransit');
      }

      // A photo of the item as received is required before payment is
      // released — unlike the traveler's shipping proof, this one gates
      // the transition.
      if (!parsed.data.image_url) {
        throw new AppError('VALIDATION_ERROR', 400, 'delivery.deliveryProofUrlRequired');
      }

      const now = new Date();
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await request.db.transaction().execute(async (trx: any) => {
        await trx
          .updateTable('orders')
          .set({
            status: 'delivered',
            delivered_at: now,
            delivery_proof_url: parsed.data.image_url,
            updated_at: now,
          })
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
            delivery_proof_url: parsed.data.image_url,
          },
        });
        await recordNotifications(trx, [
          {
            userId: order.traveler_id,
            type: 'delivered',
            params: { _variant: 'traveler', item: order.item_description },
            orderId: order.id,
          },
          {
            userId: order.shopper_id,
            type: 'delivered',
            params: { _variant: 'shopper', item: order.item_description },
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
