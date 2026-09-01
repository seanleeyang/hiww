import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';

const evidenceSchema = z.object({
  evidence_type: z.enum(['photo', 'receipt', 'document']),
  url: z.string().url(),
});

export async function registerEvidenceRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Params: { id: string }; Body: unknown }>('/api/orders/:id/evidence', async (request: any, reply: any) => {
    const parsed = evidenceSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'Invalid evidence payload');
    }

    const order = await request.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', request.params.id)
      .executeTakeFirst();

    if (!order) {
      throw new AppError('NOT_FOUND', 404, 'Order not found');
    }

    const userId = request.userId;
    if (order.shopper_id !== userId && order.traveler_id !== userId) {
      throw new AppError('FORBIDDEN', 403, 'Only order participants can upload evidence');
    }

    const evidenceId = generateId();

    await request.db
      .insertInto('evidence')
      .values({
        id: evidenceId,
        order_id: order.id,
        evidence_type: parsed.data.evidence_type,
        url: parsed.data.url,
        created_at: new Date(),
      })
      .execute();

    reply.status(201).send({
      success: true,
      data: { id: evidenceId },
      code: 'EVIDENCE_UPLOADED',
    });
  });

  app.get<{ Params: { id: string } }>('/api/orders/:id/evidence', async (request: any, reply: any) => {
    const order = await request.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', request.params.id)
      .executeTakeFirst();

    if (!order) {
      throw new AppError('NOT_FOUND', 404, 'Order not found');
    }

    const userId = request.userId;
    if (order.shopper_id !== userId && order.traveler_id !== userId) {
      throw new AppError('FORBIDDEN', 403, 'Only order participants can view evidence');
    }

    const items = await request.db
      .selectFrom('evidence')
      .selectAll()
      .where('order_id', '=', order.id)
      .orderBy('created_at', 'desc')
      .execute();

    reply.send({
      success: true,
      data: items,
      code: 'EVIDENCE_LISTED',
    });
  });
}
