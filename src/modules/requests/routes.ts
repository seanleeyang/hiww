import { FastifyInstance } from 'fastify';
import { createRequestSchema } from '@/types/schemas';
import { AppError, generateId } from '@/utils/helpers';
import { toUserSummary, USER_SUMMARY_COLUMNS } from '@/utils/user-summary';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerRequestsRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>(
    '/api/requests',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = createRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Invalid request data');
      }

      const requestId = generateId();
      await request.db
        .insertInto('requests')
        .values({
          id: requestId,
          shopper_id: request.userId,
          item_description: parsed.data.item_description,
          source_country: parsed.data.source_country,
          category: parsed.data.category,
          estimated_weight_kg: parsed.data.estimated_weight_kg,
          budget: parsed.data.budget,
          quantity: parsed.data.quantity ?? 1,
          title: parsed.data.title ?? null,
          source_city: parsed.data.source_city ?? null,
          need_by: parsed.data.need_by ? new Date(parsed.data.need_by) : null,
          image_url: parsed.data.image_url ?? null,
          status: 'open',
          created_at: new Date(),
          updated_at: new Date(),
        })
        .execute();

      reply.status(201).send({ success: true, data: { id: requestId }, code: 'REQUEST_CREATED' });
    }
  );

  // The caller's own requests, any status.
  app.get(
    '/api/requests/mine',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const items = await request.db
        .selectFrom('requests')
        .selectAll()
        .where('shopper_id', '=', request.userId)
        .orderBy('created_at', 'desc')
        .execute();
      reply.send({ success: true, data: { items }, code: 'REQUESTS_MINE' });
    }
  );

  // Marketplace browse: other people's open requests (what a traveler offers on).
  app.get<{ Querystring: { page?: string; limit?: string } }>(
    '/api/requests',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const page = Math.max(1, parseInt(request.query.page || '1', 10) || 1);
      const limit = Math.min(100, Math.max(1, parseInt(request.query.limit || '20', 10) || 20));
      const offset = (page - 1) * limit;

      let base = request.db.selectFrom('requests').where('status', '=', 'open');
      if (request.userRole !== 'admin') {
        base = base.where('shopper_id', '!=', request.userId);
      }

      const items = await base
        .selectAll()
        .orderBy('created_at', 'desc')
        .limit(limit)
        .offset(offset)
        .execute();

      reply.send({ success: true, data: { items, page, limit }, code: 'REQUESTS_LISTED' });
    }
  );

  app.get<{ Params: { id: string } }>(
    '/api/requests/:id',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const itemRequest = await request.db
        .selectFrom('requests')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!itemRequest) {
        throw new AppError('NOT_FOUND', 404, 'Request not found');
      }

      const shopper = await request.db
        .selectFrom('users')
        .select([...USER_SUMMARY_COLUMNS])
        .where('id', '=', itemRequest.shopper_id)
        .executeTakeFirst();

      reply.send({
        success: true,
        data: { ...itemRequest, shopper: shopper ? toUserSummary(shopper) : null },
        code: 'REQUEST_FOUND',
      });
    }
  );
}
