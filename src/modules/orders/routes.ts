import { FastifyInstance } from 'fastify';
import { AppError } from '@/utils/helpers';
import { toUserSummary, USER_SUMMARY_COLUMNS } from '@/utils/user-summary';
import { recordAudit, actorFromRequest } from '@/services/audit';
import { recordNotification } from '@/services/notify';
import { expireOverduePayments } from '@/services/order-expiry';

/** Drop the operator-only AI receipt fields before returning an order to a participant. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function stripReceiptCheck(order: any): any {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const { receipt_analysis, receipt_risk, receipt_reviewed_at, ...rest } = order;
  return rest;
}

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
      await expireOverduePayments(request.db);

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

      const rows = await base
        .selectAll()
        .orderBy('created_at', 'desc')
        .limit(limit)
        .offset(offset)
        .execute();

      // The list view needs the same product photo + counterparty name the
      // single-order view already sends — batched here (one query for every
      // source request, one for every counterparty) rather than the N+1 the
      // single-order route can afford to do per-request.
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const requestIds = [...new Set(rows.map((r: any) => r.request_id).filter(Boolean))];
      const requestRows = requestIds.length
        ? await request.db
            .selectFrom('requests')
            .select(['id', 'image_url', 'category'])
            .where('id', 'in', requestIds)
            .execute()
        : [];
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const requestById = new Map<string, any>(requestRows.map((r: any) => [r.id, r]));

      const counterpartyIds = [
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        ...new Set(rows.map((r: any) => (r.traveler_id === request.userId ? r.shopper_id : r.traveler_id))),
      ];
      const counterpartyRows = counterpartyIds.length
        ? await request.db
            .selectFrom('users')
            .select([...USER_SUMMARY_COLUMNS])
            .where('id', 'in', counterpartyIds)
            .execute()
        : [];
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const counterpartyById = new Map<string, any>(counterpartyRows.map((u: any) => [u.id, u]));

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const enriched = rows.map((order: any) => {
        const sourceRequest = order.request_id ? requestById.get(order.request_id) : undefined;
        const counterpartyId = order.traveler_id === request.userId ? order.shopper_id : order.traveler_id;
        const counterparty = counterpartyById.get(counterpartyId);
        return {
          ...order,
          request_image_url: sourceRequest?.image_url ?? null,
          request_category: sourceRequest?.category ?? null,
          counterparty: counterparty ? toUserSummary(counterparty) : null,
        };
      });

      // The AI receipt assessment is operator-only (the photo stays visible).
      const items = isAdmin ? enriched : enriched.map(stripReceiptCheck);

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
      await expireOverduePayments(request.db);

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'common.orderNotFound');
      }

      const isShopper = order.shopper_id === request.userId;
      const isTraveler = order.traveler_id === request.userId;
      if (!isShopper && !isTraveler && request.userRole !== 'admin') {
        throw new AppError('FORBIDDEN', 403, 'common.notPartOfOrder');
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

      // The AI receipt check is an operator tool — participants see the receipt
      // photo itself but not the risk assessment.
      const isAdmin = request.userRole === 'admin';
      const orderView = isAdmin ? order : stripReceiptCheck(order);

      reply.send({
        success: true,
        data: {
          ...orderView,
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
      await expireOverduePayments(request.db);

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'common.orderNotFound');
      }
      if (order.shopper_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'orders.onlyShopperCanReportPayment');
      }
      if (order.status !== 'pending_payment') {
        throw new AppError(
          'INVALID_STATUS',
          409,
          order.status === 'cancelled' ? 'orders.cancelledPaymentNotMadeInTime' : 'orders.notAwaitingPayment'
        );
      }

      await request.db
        .updateTable('orders')
        .set({ payment_claimed_at: new Date(), updated_at: new Date() })
        .where('id', '=', order.id)
        .execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'order.payment_claim',
        targetType: 'order',
        targetId: order.id,
        summary: `Shopper reported paying for order ${order.id} (${order.total_price}) — awaiting confirmation`,
        metadata: { total_price: order.total_price, shopper_id: order.shopper_id },
      });

      await recordNotification(request.db, {
        userId: order.traveler_id,
        type: 'payment_claimed',
        params: { item: order.item_description },
        orderId: order.id,
      });

      reply.send({
        success: true,
        data: { order_id: order.id, payment_claimed: true },
        code: 'PAYMENT_CLAIMED',
      });
    }
  );
}
