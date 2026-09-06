import { FastifyInstance } from 'fastify';
import { createRequestSchema, updateRequestSchema } from '@/types/schemas';
import { AppError, generateId } from '@/utils/helpers';
import { toUserSummary, USER_SUMMARY_COLUMNS } from '@/utils/user-summary';
import { recordAudit, actorFromRequest } from '@/services/audit';

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

  app.patch<{ Params: { id: string }; Body: unknown }>(
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
      if (itemRequest.shopper_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'Not your want');
      }
      if (itemRequest.status !== 'open') {
        throw new AppError('INVALID_STATE', 400, 'Only an open want can be edited');
      }

      const parsed = updateRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Invalid want update');
      }
      const d = parsed.data;

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const patch: Record<string, any> = { updated_at: new Date() };
      if (d.item_description !== undefined) patch.item_description = d.item_description;
      if (d.category !== undefined) patch.category = d.category;
      if (d.estimated_weight_kg !== undefined) patch.estimated_weight_kg = d.estimated_weight_kg;
      if (d.budget !== undefined) patch.budget = d.budget;
      if (d.quantity !== undefined) patch.quantity = d.quantity;
      if (d.title !== undefined) patch.title = d.title;
      if (d.source_city !== undefined) patch.source_city = d.source_city;
      if (d.need_by !== undefined) patch.need_by = new Date(d.need_by);
      if (d.image_url !== undefined) patch.image_url = d.image_url;

      await request.db.updateTable('requests').set(patch).where('id', '=', itemRequest.id).execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'request.update',
        targetType: 'request',
        targetId: itemRequest.id,
        summary: `Shopper updated want ${itemRequest.id}`,
        metadata: { fields: Object.keys(patch).filter((k) => k !== 'updated_at') },
      });

      reply.send({ success: true, data: { id: itemRequest.id }, code: 'REQUEST_UPDATED' });
    }
  );

  app.post<{ Params: { id: string } }>(
    '/api/requests/:id/cancel',
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
      if (itemRequest.shopper_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'Not your want');
      }
      if (itemRequest.status !== 'open') {
        throw new AppError('INVALID_STATE', 400, 'Want is not open');
      }

      await request.db
        .updateTable('requests')
        .set({ status: 'cancelled', updated_at: new Date() })
        .where('id', '=', itemRequest.id)
        .execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'request.cancel',
        targetType: 'request',
        targetId: itemRequest.id,
        summary: `Shopper cancelled want ${itemRequest.id}`,
        metadata: {},
      });

      reply.send({
        success: true,
        data: { id: itemRequest.id, status: 'cancelled' },
        code: 'REQUEST_CANCELLED',
      });
    }
  );
}
