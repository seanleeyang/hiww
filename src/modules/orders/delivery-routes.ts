import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError } from '@/utils/helpers';

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

      if (order.status !== 'confirmed') {
        throw new AppError('INVALID_STATUS', 409, 'Order must be confirmed before delivery');
      }

      await request.db
        .updateTable('orders')
        .set({ status: 'in_transit', updated_at: new Date() })
        .where('id', '=', order.id)
        .execute();

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

      await request.db
        .updateTable('orders')
        .set({ status: 'delivered', updated_at: new Date() })
        .where('id', '=', order.id)
        .execute();

      reply.send({
        success: true,
        data: { order_id: order.id, status: 'delivered' },
        code: 'ORDER_RELEASED',
      });
    }
  );
}
