import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError } from '@/utils/helpers';

const resolveDisputeSchema = z.object({
  status: z.enum(['resolved', 'closed']),
  resolution: z.string().min(10),
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
  app.post<{ Params: { id: string }; Body: unknown }>('/api/admin/disputes/:id/resolve', async (request: any, reply: any) => {
    const parsed = resolveDisputeSchema.safeParse(request.body);
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
      code: 'DISPUTE_RESOLVED_BY_ADMIN',
    });
  });

  app.post<{ Params: { userId: string }; Body: unknown }>('/api/admin/users/:userId/kyc-review', async (request: any, reply: any) => {
    const parsed = reviewKycSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'Invalid KYC review payload');
    }

    const user = await request.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', request.params.userId)
      .executeTakeFirst();

    if (!user) {
      throw new AppError('NOT_FOUND', 404, 'User not found');
    }

    await request.db
      .updateTable('users')
      .set({
        kyc_status: parsed.data.status,
        updated_at: new Date(),
      })
      .where('id', '=', user.id)
      .execute();

    reply.send({
      success: true,
      data: { user_id: user.id, kyc_status: parsed.data.status, note: parsed.data.note },
      code: 'KYC_REVIEWED_BY_ADMIN',
    });
  });

  app.post<{ Params: { userId: string }; Body: unknown }>('/api/admin/users/:userId/flag', async (request: any, reply: any) => {
    const parsed = flagUserSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'Invalid risk flag payload');
    }

    const user = await request.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', request.params.userId)
      .executeTakeFirst();

    if (!user) {
      throw new AppError('NOT_FOUND', 404, 'User not found');
    }

    await request.db
      .updateTable('users')
      .set({
        risk_status: parsed.data.risk_status,
        updated_at: new Date(),
      })
      .where('id', '=', user.id)
      .execute();

    reply.send({
      success: true,
      data: { user_id: user.id, risk_status: parsed.data.risk_status, reason: parsed.data.reason },
      code: 'USER_RISK_FLAGGED',
    });
  });
}
