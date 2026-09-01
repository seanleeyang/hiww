import { FastifyInstance } from 'fastify';
import { AppError } from '@/utils/helpers';

export async function registerAdminRoutes(app: FastifyInstance): Promise<void> {
  app.get('/api/admin/reviews', async (request: any, reply: any) => {
    try {
      const openDisputes = await request.db
        .selectFrom('disputes')
        .selectAll()
        .where('status', 'in', ['open', 'in_review'])
        .orderBy('created_at', 'desc')
        .execute();

      const pendingKyc = await request.db
        .selectFrom('users')
        .select(['id', 'email', 'full_name', 'kyc_status', 'created_at'])
        .where('kyc_status', 'in', ['pending', 'rejected'])
        .orderBy('created_at', 'desc')
        .execute();

      const queue = [
        ...openDisputes.map((dispute: any) => ({
          type: 'dispute',
          id: dispute.id,
          status: dispute.status,
          order_id: dispute.order_id,
          initiator_id: dispute.initiator_id,
          reason: dispute.reason,
          resolution: dispute.resolution ?? null,
          created_at: dispute.created_at,
        })),
        ...pendingKyc.map((user: any) => ({
          type: 'kyc',
          id: user.id,
          status: user.kyc_status,
          user_id: user.id,
          email: user.email,
          full_name: user.full_name,
          created_at: user.created_at,
        })),
      ].sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

      reply.send({
        success: true,
        data: {
          count: queue.length,
          queue,
        },
        code: 'ADMIN_REVIEWS',
      });
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw new AppError('DB_ERROR', 500, 'Failed to load admin review queue');
    }
  });
}
