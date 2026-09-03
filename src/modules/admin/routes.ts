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

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.get('/api/admin/users', async (request: any, reply: any) => {
    const users = await request.db
      .selectFrom('users')
      .select(['id', 'email', 'full_name', 'user_type', 'role', 'kyc_status', 'risk_status', 'created_at'])
      .orderBy('created_at', 'desc')
      .limit(200)
      .execute();

    reply.send({ success: true, data: { users }, code: 'ADMIN_USERS' });
  });

  // Append-only audit trail. Filter by ?action=, ?target_type=, ?target_id=,
  // ?actor_id=; page with ?limit= (max 200) and ?before= (an ISO timestamp).
  app.get<{
    Querystring: {
      action?: string;
      target_type?: string;
      target_id?: string;
      actor_id?: string;
      limit?: string;
      before?: string;
    };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  }>('/api/admin/audit', async (request: any, reply: any) => {
    const q = request.query;
    const limit = Math.min(200, Math.max(1, parseInt(q.limit || '50', 10) || 50));

    let query = request.db.selectFrom('audit_log').selectAll();
    if (q.action) query = query.where('action', '=', q.action);
    if (q.target_type) query = query.where('target_type', '=', q.target_type);
    if (q.target_id) query = query.where('target_id', '=', q.target_id);
    if (q.actor_id) query = query.where('actor_id', '=', q.actor_id);
    if (q.before) {
      const ts = new Date(q.before);
      if (!Number.isNaN(ts.getTime())) query = query.where('created_at', '<', ts);
    }

    const items = await query.orderBy('created_at', 'desc').limit(limit).execute();

    reply.send({ success: true, data: { items, limit }, code: 'ADMIN_AUDIT' });
  });
}
