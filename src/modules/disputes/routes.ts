import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';

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

    reply.send({
      success: true,
      data: { id: dispute.id, status: parsed.data.status },
      code: 'DISPUTE_RESOLVED',
    });
  });
}
