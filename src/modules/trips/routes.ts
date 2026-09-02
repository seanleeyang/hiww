import { FastifyInstance } from 'fastify';
import { createTripSchema } from '@/types/schemas';
import { AppError, generateId } from '@/utils/helpers';
import { toUserSummary, USER_SUMMARY_COLUMNS } from '@/utils/user-summary';

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
      await request.db
        .insertInto('trips')
        .values({
          id: tripId,
          traveler_id: request.userId,
          departure_country: parsed.data.departure_country,
          arrival_country: parsed.data.arrival_country,
          departure_date: new Date(parsed.data.departure_date),
          return_date: new Date(parsed.data.return_date),
          max_weight_kg: parsed.data.max_weight_kg,
          max_items: parsed.data.max_items,
          title: parsed.data.title ?? null,
          departure_city: parsed.data.departure_city ?? null,
          arrival_city: parsed.data.arrival_city ?? null,
          note: parsed.data.note ?? null,
          cover_image_url: parsed.data.cover_image_url ?? null,
          status: 'published',
          created_at: new Date(),
          updated_at: new Date(),
        })
        .execute();

      reply.status(201).send({ success: true, data: { id: tripId }, code: 'TRIP_CREATED' });
    }
  );

  app.get(
    '/api/trips/mine',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const items = await request.db
        .selectFrom('trips')
        .selectAll()
        .where('traveler_id', '=', request.userId)
        .orderBy('created_at', 'desc')
        .execute();
      reply.send({ success: true, data: { items }, code: 'TRIPS_MINE' });
    }
  );

  app.get<{ Querystring: { page?: string; limit?: string } }>(
    '/api/trips',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const page = Math.max(1, parseInt(request.query.page || '1', 10) || 1);
      const limit = Math.min(100, Math.max(1, parseInt(request.query.limit || '20', 10) || 20));
      const offset = (page - 1) * limit;

      const items = await request.db
        .selectFrom('trips')
        .selectAll()
        .where('status', '=', 'published')
        .orderBy('departure_date', 'asc')
        .limit(limit)
        .offset(offset)
        .execute();

      reply.send({ success: true, data: { items, page, limit }, code: 'TRIPS_LISTED' });
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

      const traveler = await request.db
        .selectFrom('users')
        .select([...USER_SUMMARY_COLUMNS])
        .where('id', '=', trip.traveler_id)
        .executeTakeFirst();

      reply.send({
        success: true,
        data: { ...trip, traveler: traveler ? toUserSummary(traveler) : null },
        code: 'TRIP_FOUND',
      });
    }
  );
}
