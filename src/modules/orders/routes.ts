import { FastifyInstance } from 'fastify';
import { AppError } from '@/utils/helpers';
import { toUserSummary, USER_SUMMARY_COLUMNS } from '@/utils/user-summary';

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

      const isShopper = order.shopper_id === request.userId;
      const isTraveler = order.traveler_id === request.userId;
      if (!isShopper && !isTraveler && request.userRole !== 'admin') {
        throw new AppError('FORBIDDEN', 403, 'You are not part of this order');
      }

      // The other party, for the order tracker header.
      const counterpartyId = isTraveler ? order.shopper_id : order.traveler_id;
      const counterparty = await request.db
        .selectFrom('users')
        .select([...USER_SUMMARY_COLUMNS])
        .where('id', '=', counterpartyId)
        .executeTakeFirst();

      // Review state for the current viewer.
      let myReview = null;
      if (isShopper || isTraveler) {
        myReview = await request.db
          .selectFrom('reviews')
          .select(['id', 'rating', 'comment', 'created_at'])
          .where('order_id', '=', order.id)
          .where('reviewer_id', '=', request.userId)
          .executeTakeFirst();
      }

      // The original request's photo/category, for the tracker's product image.
      const sourceRequest = order.request_id
        ? await request.db
            .selectFrom('requests')
            .select(['image_url', 'category'])
            .where('id', '=', order.request_id)
            .executeTakeFirst()
        : undefined;

      reply.send({
        success: true,
        data: {
          ...order,
          counterparty: counterparty ? toUserSummary(counterparty) : null,
          request_image_url: sourceRequest?.image_url ?? null,
          request_category: sourceRequest?.category ?? null,
          my_review: myReview ?? null,
          can_review: (isShopper || isTraveler) && order.status === 'delivered' && !myReview,
        },
        code: 'ORDER_FOUND',
      });
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
