import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError } from '@/utils/helpers';
import { getIdentityProvider } from '@/services/providers';

const identityVerifySchema = z.object({
  document_type: z.enum(['passport', 'id_card', 'drivers_license']),
  document_id: z.string().min(3),
});

export async function registerExternalRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>('/api/identity/verify', async (request: any, reply: any) => {
    const parsed = identityVerifySchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'external.invalidPayload');
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

    const identityProvider = getIdentityProvider();
    const verification = await identityProvider.verify(user.id, parsed.data.document_type, parsed.data.document_id);

    await request.db
      .updateTable('users')
      .set({ kyc_status: verification.status === 'verified' ? 'approved' : 'rejected', updated_at: new Date() })
      .where('id', '=', user.id)
      .execute();

    reply.send({
      success: true,
      data: verification,
      code: 'IDENTITY_VERIFIED',
    });
  });
}
