import { FastifyInstance } from 'fastify';
import { createTripSchema } from '@/types/schemas';
import { AppError, generateId } from '@/utils/helpers';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerTripsRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>(
    '/api/trips',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = createTripSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Invalid trip data');
      }

      const tripId = generateId();
      const travelerId = request.userId!;

      try {
        await request.db
          .insertInto('trips')
          .values({
            id: tripId,
            traveler_id: travelerId,
            departure_country: parsed.data.departure_country,
            arrival_country: parsed.data.arrival_country,
            departure_date: new Date(parsed.data.departure_date),
            return_date: new Date(parsed.data.return_date),
            max_weight_kg: parsed.data.max_weight_kg,
            max_items: parsed.data.max_items,
            status: 'published',
            created_at: new Date(),
            updated_at: new Date(),
          })
          .execute();

        reply.status(201).send({
          success: true,
          data: { id: tripId },
          code: 'TRIP_CREATED',
        });
      } catch (error) {
        throw new AppError('DB_ERROR', 500, 'Failed to create trip');
      }
    }
  );

  app.get<{ Params: { id: string } }>(
    '/api/trips/:id',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const trip = await request.db
        .selectFrom('trips')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!trip) {
        throw new AppError('NOT_FOUND', 404, 'Trip not found');
      }

      reply.send({ success: true, data: trip, code: 'TRIP_FOUND' });
    }
  );

  app.get<{ Querystring: { page?: string; limit?: string } }>(
    '/api/trips',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const page = parseInt((request.query as { page?: string }).page || '1');
      const limit = parseInt((request.query as { limit?: string }).limit || '10');
      const offset = (page - 1) * limit;

      const trips = await request.db
        .selectFrom('trips')
        .selectAll()
        .limit(limit)
        .offset(offset)
        .execute();

      const countResult = await request.db
        .selectFrom('trips')
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        .select((db: any) => [db.fn.count('id').as('count')])
        .executeTakeFirst();

      const total = countResult?.count || 0;

      reply.send({
        success: true,
        data: {
          items: trips,
          total,
          page,
          limit,
          totalPages: Math.ceil(total / limit),
        },
        code: 'TRIPS_LISTED',
      });
    }
  );
}
