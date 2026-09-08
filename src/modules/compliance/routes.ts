import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError } from '@/utils/helpers';

const kycSubmitSchema = z.object({
  document_type: z.enum(['passport', 'id_card', 'drivers_license']),
  document_id: z.string().min(3),
});

const kycReviewSchema = z.object({
  user_id: z.string().uuid(),
  status: z.enum(['approved', 'rejected', 'pending']),
});

export async function registerComplianceRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>('/api/compliance/kyc/submit', async (request: any, reply: any) => {
    const parsed = kycSubmitSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'compliance.invalidKycSubmission');
    }

    const userId = request.userId;
    if (!userId) {
      throw new AppError('AUTH_ERROR', 401, 'common.authRequired');
    }

    const user = await request.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', userId)
      .executeTakeFirst();

    if (!user) {
      throw new AppError('NOT_FOUND', 404, 'common.userNotFound');
    }

    await request.db
      .updateTable('users')
      .set({ kyc_status: 'pending', updated_at: new Date() })
      .where('id', '=', user.id)
      .execute();

    reply.status(201).send({
      success: true,
      data: { user_id: user.id, kyc_status: 'pending' },
      code: 'KYC_SUBMITTED',
    });
  });

  app.post<{ Body: unknown }>('/api/compliance/kyc/approve', async (request: any, reply: any) => {
    const parsed = kycReviewSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'common.invalidKycReviewPayload');
    }

    const user = await request.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', parsed.data.user_id)
      .executeTakeFirst();

    if (!user) {
      throw new AppError('NOT_FOUND', 404, 'common.userNotFound');
    }

    await request.db
      .updateTable('users')
      .set({ kyc_status: parsed.data.status, updated_at: new Date() })
      .where('id', '=', user.id)
      .execute();

    reply.send({
      success: true,
      data: { user_id: user.id, kyc_status: parsed.data.status },
      code: 'KYC_REVIEWED',
    });
  });
}
