import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';
import { requireOrderParticipant } from '@/utils/order-participant';

const evidenceSchema = z.object({
  evidence_type: z.enum(['photo', 'receipt', 'document']),
  url: z.string().url(),
});

export async function registerEvidenceRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Params: { id: string }; Body: unknown }>('/api/orders/:id/evidence', async (request: any, reply: any) => {
    const parsed = evidenceSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'evidence.invalidPayload');
    }

    const order = await requireOrderParticipant(request.db, request.userId, request.params.id, 'evidence.onlyParticipantsUpload');

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
    const order = await requireOrderParticipant(request.db, request.userId, request.params.id, 'evidence.onlyParticipantsView');

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
