import { FastifyInstance } from 'fastify';
import { createRequestSchema } from '@/types/schemas';
import { AppError, generateId } from '@/utils/helpers';

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
      const shopperId = request.userId!;

      try {
        await request.db
          .insertInto('requests')
          .values({
            id: requestId,
            shopper_id: shopperId,
            item_description: parsed.data.item_description,
            source_country: parsed.data.source_country,
            category: parsed.data.category,
            estimated_weight_kg: parsed.data.estimated_weight_kg,
            budget: parsed.data.budget,
            status: 'open',
            created_at: new Date(),
            updated_at: new Date(),
          })
          .execute();

        reply.status(201).send({
          success: true,
          data: { id: requestId },
          code: 'REQUEST_CREATED',
        });
      } catch (error) {
        throw new AppError('DB_ERROR', 500, 'Failed to create request');
      }
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

      reply.send({ success: true, data: itemRequest, code: 'REQUEST_FOUND' });
    }
  );

  app.get<{ Querystring: { page?: string; limit?: string } }>(
    '/api/requests',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const page = parseInt((request.query as { page?: string }).page || '1');
      const limit = parseInt((request.query as { limit?: string }).limit || '10');
      const offset = (page - 1) * limit;

      const requests = await request.db
        .selectFrom('requests')
        .selectAll()
        .limit(limit)
        .offset(offset)
        .execute();

      const countResult = await request.db
        .selectFrom('requests')
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        .select((db: any) => [db.fn.count('id').as('count')])
        .executeTakeFirst();

      const total = countResult?.count || 0;

      reply.send({
        success: true,
        data: {
          items: requests,
          total,
          page,
          limit,
          totalPages: Math.ceil(total / limit),
        },
        code: 'REQUESTS_LISTED',
      });
    }
  );
}
