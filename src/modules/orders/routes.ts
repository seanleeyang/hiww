import { FastifyInstance } from 'fastify';
import { AppError } from '@/utils/helpers';

/**
 * Orders are created by accepting an offer (see offers/routes.ts). This module
 * only reads orders and records the shopper's "I've paid" signal. Reads are
 * scoped to the caller — a user sees only orders they are part of; an admin
 * sees everything.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerOrdersRoutes(app: FastifyInstance): Promise<void> {
  app.get<{ Querystring: { page?: string; limit?: string } }>(
    '/api/orders',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const page = Math.max(1, parseInt(request.query.page || '1', 10) || 1);
      const limit = Math.min(100, Math.max(1, parseInt(request.query.limit || '20', 10) || 20));
      const offset = (page - 1) * limit;
      const isAdmin = request.userRole === 'admin';

      let base = request.db.selectFrom('orders');
      if (!isAdmin) {
        base = base.where((eb: any) =>
          eb.or([eb('shopper_id', '=', request.userId), eb('traveler_id', '=', request.userId)])
        );
      }

      const items = await base
        .selectAll()
        .orderBy('created_at', 'desc')
        .limit(limit)
        .offset(offset)
        .execute();

      reply.send({
        success: true,
        data: { items, page, limit },
        code: 'ORDERS_LISTED',
      });
    }
  );

  app.get<{ Params: { id: string } }>(
    '/api/orders/:id',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'Order not found');
      }

      const isParticipant = order.shopper_id === request.userId || order.traveler_id === request.userId;
      if (!isParticipant && request.userRole !== 'admin') {
        throw new AppError('FORBIDDEN', 403, 'You are not part of this order');
      }

      reply.send({ success: true, data: order, code: 'ORDER_FOUND' });
    }
  );

  app.post<{ Params: { id: string } }>(
    '/api/orders/:id/claim-payment',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'Order not found');
      }
      if (order.shopper_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'Only the shopper can report a payment');
      }
      if (order.status !== 'pending_payment') {
        throw new AppError('INVALID_STATUS', 409, 'This order is not awaiting payment');
      }

      await request.db
        .updateTable('orders')
        .set({ payment_claimed_at: new Date(), updated_at: new Date() })
        .where('id', '=', order.id)
        .execute();

      reply.send({
        success: true,
        data: { order_id: order.id, payment_claimed: true },
        code: 'PAYMENT_CLAIMED',
      });
    }
  );
}
