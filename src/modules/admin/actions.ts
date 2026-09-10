import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';
import { recordAudit, actorFromRequest } from '@/services/audit';
import { recordNotification, recordNotifications } from '@/services/notify';

const resolveDisputeSchema = z.object({
  status: z.enum(['resolved', 'closed']),
  resolution: z.string().min(10),
});

const cancelOrderSchema = z.object({
  reason: z.string().min(10),
  dispute_id: z.string().uuid().optional(),
});

const refundOrderSchema = z.object({
  method: z.string().min(2).max(40),
  reference: z.string().min(1).max(120),
  note: z.string().max(500).optional(),
});

const reviewKycSchema = z.object({
  status: z.enum(['approved', 'rejected', 'pending']),
  note: z.string().min(3),
});

const flagUserSchema = z.object({
  risk_status: z.enum(['clear', 'flagged', 'restricted']),
  reason: z.string().min(3),
});

export async function registerAdminActionRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Params: { id: string }; Body: unknown }>('/api/admin/disputes/:id/resolve', async (request, reply) => {
    const parsed = resolveDisputeSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'adminActions.invalidDisputeResolution');
    }

    const dispute = await request.db
      .selectFrom('disputes')
      .selectAll()
      .where('id', '=', request.params.id)
      .executeTakeFirst();

    if (!dispute) {
      throw new AppError('NOT_FOUND', 404, 'common.disputeNotFound');
    }

    if (dispute.status !== 'open') {
      throw new AppError('INVALID_STATUS', 409, 'disputes.notOpen');
    }

    // Guarded by prior status — two concurrent resolve calls (e.g. two admin
    // tabs) can't both fall through and both write/re-notify.
    const resolved = await request.db
      .updateTable('disputes')
      .set({
        status: parsed.data.status,
        resolution: parsed.data.resolution,
        updated_at: new Date(),
      })
      .where('id', '=', dispute.id)
      .where('status', '=', 'open')
      .returning('id')
      .execute();
    if (resolved.length === 0) {
      throw new AppError('INVALID_STATUS', 409, 'disputes.notOpen');
    }

    await recordAudit(request.db, actorFromRequest(request), {
      action: 'dispute.resolve',
      targetType: 'dispute',
      targetId: dispute.id,
      summary: `Dispute ${dispute.id} on order ${dispute.order_id} marked ${parsed.data.status}`,
      metadata: {
        order_id: dispute.order_id,
        from_status: dispute.status,
        to_status: parsed.data.status,
        resolution: parsed.data.resolution,
      },
    });

    reply.send({
      success: true,
      data: { id: dispute.id, status: parsed.data.status },
      code: 'DISPUTE_RESOLVED_BY_ADMIN',
    });
  });

  // Force-cancel an order at any point in its life — the intervention power
  // the normal user/participant flows don't have (the only other thing that
  // ever cancels an order is the payment-timeout auto-expiry, and only while
  // still `pending_payment`). Optionally resolves a linked dispute in the
  // same action, so an admin can act directly from a dispute's detail view.
  app.post<{ Params: { id: string }; Body: unknown }>('/api/admin/orders/:id/cancel', async (request, reply) => {
    const parsed = cancelOrderSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'adminActions.invalidCancelPayload');
    }

    const order = await request.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', request.params.id)
      .executeTakeFirst();
    if (!order) {
      throw new AppError('NOT_FOUND', 404, 'common.orderNotFound');
    }
    if (order.status === 'cancelled') {
      throw new AppError('INVALID_STATUS', 409, 'adminActions.orderAlreadyCancelled');
    }

    // Money that already left the platform can't be clawed back by flipping
    // a status flag — cancelling past that point would just create a
    // confusing state with no real effect.
    const existingPayout = await request.db
      .selectFrom('payouts')
      .select('id')
      .where('order_id', '=', order.id)
      .executeTakeFirst();
    if (existingPayout) {
      throw new AppError('INVALID_STATUS', 409, 'adminActions.orderAlreadyPaidOut');
    }

    let dispute: { id: string; status: string; order_id: string } | undefined;
    if (parsed.data.dispute_id) {
      dispute = await request.db
        .selectFrom('disputes')
        .select(['id', 'status', 'order_id'])
        .where('id', '=', parsed.data.dispute_id)
        .executeTakeFirst();
      if (!dispute || dispute.order_id !== order.id) {
        throw new AppError('NOT_FOUND', 404, 'common.disputeNotFound');
      }
      if (dispute.status !== 'open') {
        throw new AppError('INVALID_STATUS', 409, 'disputes.notOpen');
      }
    }

    const now = new Date();
    const refundOwed = order.confirmed_at !== null;

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let cancelled = false;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await request.db.transaction().execute(async (trx: any) => {
      // Guarded by "not already cancelled" rather than one exact prior
      // status — admin can cancel from any live status. A concurrent
      // double-cancel can't both fall through and double-notify below.
      const result = await trx
        .updateTable('orders')
        .set({ status: 'cancelled', cancelled_at: now, updated_at: now })
        .where('id', '=', order.id)
        .where('status', '!=', 'cancelled')
        .returning('id')
        .execute();
      if (result.length === 0) return;
      cancelled = true;

      if (dispute) {
        await trx
          .updateTable('disputes')
          .set({ status: 'resolved', resolution: parsed.data.reason, updated_at: now })
          .where('id', '=', dispute.id)
          .where('status', '=', 'open')
          .execute();
      }

      await recordAudit(trx, actorFromRequest(request), {
        action: 'order.admin_cancel',
        targetType: 'order',
        targetId: order.id,
        summary: `Admin cancelled order ${order.id}: ${parsed.data.reason}`,
        metadata: {
          from_status: order.status,
          reason: parsed.data.reason,
          dispute_id: dispute?.id ?? null,
          refund_owed: refundOwed,
        },
      });

      await recordNotifications(trx, [
        {
          userId: order.shopper_id,
          type: 'order_cancelled',
          params: { item: order.item_description, reason: parsed.data.reason },
          orderId: order.id,
        },
        {
          userId: order.traveler_id,
          type: 'order_cancelled',
          params: { item: order.item_description, reason: parsed.data.reason },
          orderId: order.id,
        },
      ]);

      if (refundOwed) {
        const refundAmount = order.shopper_total ?? order.total_price;
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const admins = await trx.selectFrom('users').select(['id']).where('role', '=', 'admin').execute();
        await recordNotifications(
          trx,
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          admins.map((a: any) => ({
            userId: a.id,
            type: 'refund_due' as const,
            params: { item: order.item_description, amount: refundAmount },
            orderId: order.id,
          }))
        );
      }
    });

    reply.send({
      success: true,
      data: { id: order.id, status: 'cancelled', refund_owed: refundOwed, cancelled },
      code: 'ORDER_CANCELLED_BY_ADMIN',
    });
  });

  // Record that the operator has refunded the shopper out of band — only
  // once the order is cancelled and only if payment had actually been
  // confirmed. Mirrors `/api/payments/payout`'s shape exactly.
  app.post<{ Params: { id: string }; Body: unknown }>('/api/admin/orders/:id/refund', async (request, reply) => {
    const parsed = refundOrderSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'adminActions.invalidRefundPayload');
    }

    const order = await request.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', request.params.id)
      .executeTakeFirst();
    if (!order) {
      throw new AppError('NOT_FOUND', 404, 'common.orderNotFound');
    }
    if (order.status !== 'cancelled' || order.confirmed_at === null) {
      throw new AppError('INVALID_STATUS', 409, 'money.onlyCancelledCanRefund');
    }

    const existing = await request.db
      .selectFrom('refunds')
      .select('id')
      .where('order_id', '=', order.id)
      .executeTakeFirst();
    if (existing) {
      throw new AppError('ALREADY_DONE', 409, 'money.alreadyRefunded');
    }

    // Server-authoritative, never trusts a client-sent amount — what the
    // shopper actually paid in under the pricing-breakdown snapshot, falling
    // back to goods price + fee for orders created before that snapshot existed.
    const refundAmount =
      order.shopper_total ?? String(Number(order.total_price) + Number(order.fees));

    const refundId = generateId();
    await request.db
      .insertInto('refunds')
      .values({
        id: refundId,
        order_id: order.id,
        recorded_by: request.userId ?? null,
        amount: refundAmount,
        method: parsed.data.method,
        reference: parsed.data.reference,
        note: parsed.data.note ?? null,
        created_at: new Date(),
      })
      .execute();

    await recordAudit(request.db, actorFromRequest(request), {
      action: 'order.refund',
      targetType: 'order',
      targetId: order.id,
      summary: `Refund of ${refundAmount} to shopper for order ${order.id} via ${parsed.data.method} (${parsed.data.reference})`,
      metadata: {
        refund_id: refundId,
        amount: refundAmount,
        method: parsed.data.method,
        reference: parsed.data.reference,
        shopper_id: order.shopper_id,
      },
    });

    await recordNotification(request.db, {
      userId: order.shopper_id,
      type: 'refund_sent',
      params: {
        amount: refundAmount,
        item: order.item_description,
        method: parsed.data.method,
        reference: parsed.data.reference,
      },
      orderId: order.id,
    });

    reply.status(201).send({
      success: true,
      data: { id: refundId, order_id: order.id, amount: refundAmount },
      code: 'REFUND_RECORDED',
    });
  });

  app.post<{ Params: { userId: string }; Body: unknown }>('/api/admin/users/:userId/kyc-review', async (request, reply) => {
    const parsed = reviewKycSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'common.invalidKycReviewPayload');
    }

    const user = await request.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', request.params.userId)
      .executeTakeFirst();

    if (!user) {
      throw new AppError('NOT_FOUND', 404, 'common.userNotFound');
    }

    await request.db
      .updateTable('users')
      .set({
        kyc_status: parsed.data.status,
        updated_at: new Date(),
      })
      .where('id', '=', user.id)
      .execute();

    await recordAudit(request.db, actorFromRequest(request), {
      action: 'kyc.review',
      targetType: 'user',
      targetId: user.id,
      summary: `KYC for ${user.email} set to ${parsed.data.status}`,
      metadata: {
        from_status: user.kyc_status,
        to_status: parsed.data.status,
        note: parsed.data.note,
      },
    });

    reply.send({
      success: true,
      data: { user_id: user.id, kyc_status: parsed.data.status, note: parsed.data.note },
      code: 'KYC_REVIEWED_BY_ADMIN',
    });
  });

  app.post<{ Params: { userId: string }; Body: unknown }>('/api/admin/users/:userId/flag', async (request, reply) => {
    const parsed = flagUserSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'adminActions.invalidRiskFlag');
    }

    const user = await request.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', request.params.userId)
      .executeTakeFirst();

    if (!user) {
      throw new AppError('NOT_FOUND', 404, 'common.userNotFound');
    }

    await request.db
      .updateTable('users')
      .set({
        risk_status: parsed.data.risk_status,
        updated_at: new Date(),
      })
      .where('id', '=', user.id)
      .execute();

    await recordAudit(request.db, actorFromRequest(request), {
      action: 'user.flag',
      targetType: 'user',
      targetId: user.id,
      summary: `Risk status for ${user.email} set to ${parsed.data.risk_status}`,
      metadata: {
        from_status: user.risk_status,
        to_status: parsed.data.risk_status,
        reason: parsed.data.reason,
      },
    });

    reply.send({
      success: true,
      data: { user_id: user.id, risk_status: parsed.data.risk_status, reason: parsed.data.reason },
      code: 'USER_RISK_FLAGGED',
    });
  });
}
