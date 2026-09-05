import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';
import { recordAudit, actorFromRequest } from '@/services/audit';
import { recordNotification, recordNotifications } from '@/services/notify';

const disputeSchema = z.object({
  order_id: z.string().uuid(),
  reason: z.string().min(10),
});

const resolveSchema = z.object({
  resolution: z.string().min(10),
  status: z.enum(['resolved', 'closed']).default('resolved'),
});

export async function registerDisputesRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>('/api/disputes', async (request: any, reply: any) => {
    const parsed = disputeSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'Invalid dispute payload');
    }

    const order = await request.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', parsed.data.order_id)
      .executeTakeFirst();

    if (!order) {
      throw new AppError('NOT_FOUND', 404, 'Order not found');
    }

    const initiatorId = request.userId;
    if (order.shopper_id !== initiatorId && order.traveler_id !== initiatorId) {
      throw new AppError('FORBIDDEN', 403, 'Only order participants can open disputes');
    }

    const disputeId = generateId();

    await request.db
      .insertInto('disputes')
      .values({
        id: disputeId,
        order_id: parsed.data.order_id,
        initiator_id: initiatorId,
        reason: parsed.data.reason,
        status: 'open',
        created_at: new Date(),
        updated_at: new Date(),
      })
      .execute();

    await recordAudit(request.db, actorFromRequest(request), {
      action: 'dispute.open',
      targetType: 'dispute',
      targetId: disputeId,
      summary: `Dispute opened on order ${parsed.data.order_id}`,
      metadata: {
        order_id: parsed.data.order_id,
        reason: parsed.data.reason,
        order_status: order.status,
      },
    });

    const otherParty =
      order.shopper_id === initiatorId ? order.traveler_id : order.shopper_id;
    await recordNotification(request.db, {
      userId: otherParty,
      type: 'dispute_opened',
      subject: 'A dispute was opened on your order',
      body: `The other party opened a dispute on "${order.item_description}". Hiww will review it and be in touch.`,
      orderId: order.id,
    });

    reply.status(201).send({
      success: true,
      data: { id: disputeId },
      code: 'DISPUTE_CREATED',
    });
  });

  app.post<{ Params: { id: string }; Body: unknown }>('/api/disputes/:id/resolve', async (request: any, reply: any) => {
    const parsed = resolveSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'Invalid dispute resolution payload');
    }

    const dispute = await request.db
      .selectFrom('disputes')
      .selectAll()
      .where('id', '=', request.params.id)
      .executeTakeFirst();

    if (!dispute) {
      throw new AppError('NOT_FOUND', 404, 'Dispute not found');
    }

    if (dispute.status !== 'open') {
      throw new AppError('INVALID_STATUS', 409, 'Dispute is not open');
    }

    await request.db
      .updateTable('disputes')
      .set({
        status: parsed.data.status,
        resolution: parsed.data.resolution,
        updated_at: new Date(),
      })
      .where('id', '=', dispute.id)
      .execute();

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

    const disputedOrder = await request.db
      .selectFrom('orders')
      .select(['id', 'shopper_id', 'traveler_id', 'item_description'])
      .where('id', '=', dispute.order_id)
      .executeTakeFirst();
    if (disputedOrder) {
      await recordNotifications(
        request.db,
        [disputedOrder.shopper_id, disputedOrder.traveler_id].map((userId: string) => ({
          userId,
          type: 'dispute_resolved' as const,
          subject: `Dispute ${parsed.data.status}`,
          body: `Hiww ${parsed.data.status} the dispute on "${disputedOrder.item_description}": ${parsed.data.resolution}`,
          orderId: disputedOrder.id,
        }))
      );
    }

    reply.send({
      success: true,
      data: { id: dispute.id, status: parsed.data.status },
      code: 'DISPUTE_RESOLVED',
    });
  });
}
