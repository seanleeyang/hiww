import { FastifyInstance } from 'fastify';
import { createTripSchema, updateTripSchema } from '@/types/schemas';
import { AppError, generateId } from '@/utils/helpers';
import { toUserSummary, USER_SUMMARY_COLUMNS } from '@/utils/user-summary';
import { recordAudit, actorFromRequest } from '@/services/audit';

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
        .where('return_date', '>=', new Date())
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

  app.patch<{ Params: { id: string }; Body: unknown }>(
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
      if (trip.traveler_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'Not your trip');
      }
      if (trip.status !== 'published') {
        throw new AppError('INVALID_STATE', 400, 'Only a published trip can be edited');
      }

      const parsed = updateTripSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Invalid trip update');
      }
      const d = parsed.data;

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const patch: Record<string, any> = { updated_at: new Date() };
      if (d.departure_date !== undefined) patch.departure_date = new Date(d.departure_date);
      if (d.return_date !== undefined) patch.return_date = new Date(d.return_date);
      if (d.max_weight_kg !== undefined) patch.max_weight_kg = d.max_weight_kg;
      if (d.max_items !== undefined) patch.max_items = d.max_items;
      if (d.title !== undefined) patch.title = d.title;
      if (d.departure_city !== undefined) patch.departure_city = d.departure_city;
      if (d.arrival_city !== undefined) patch.arrival_city = d.arrival_city;
      if (d.note !== undefined) patch.note = d.note;
      if (d.cover_image_url !== undefined) patch.cover_image_url = d.cover_image_url;

      const effectiveDeparture = new Date(patch.departure_date ?? trip.departure_date);
      const effectiveReturn = new Date(patch.return_date ?? trip.return_date);
      if (effectiveReturn <= effectiveDeparture) {
        throw new AppError('VALIDATION_ERROR', 400, 'Return date must be after departure');
      }

      await request.db.updateTable('trips').set(patch).where('id', '=', trip.id).execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'trip.update',
        targetType: 'trip',
        targetId: trip.id,
        summary: `Traveler updated trip ${trip.id}`,
        metadata: { fields: Object.keys(patch).filter((k) => k !== 'updated_at') },
      });

      reply.send({ success: true, data: { id: trip.id }, code: 'TRIP_UPDATED' });
    }
  );

  app.post<{ Params: { id: string } }>(
    '/api/trips/:id/cancel',
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
      if (trip.traveler_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'Not your trip');
      }
      if (trip.status !== 'published') {
        throw new AppError('INVALID_STATE', 400, 'Trip is not active');
      }

      // A trip can carry many shoppers' orders at once — block cancellation
      // while any of them are still in flight, so no one gets stranded.
      const activeOrder = await request.db
        .selectFrom('orders')
        .select(['id'])
        .where('trip_id', '=', trip.id)
        .where('status', '!=', 'delivered')
        .executeTakeFirst();
      if (activeOrder) {
        throw new AppError(
          'TRIP_HAS_ACTIVE_ORDERS',
          400,
          'This trip has an order still in progress — it must be delivered first'
        );
      }

      await request.db
        .updateTable('trips')
        .set({ status: 'cancelled', updated_at: new Date() })
        .where('id', '=', trip.id)
        .execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'trip.cancel',
        targetType: 'trip',
        targetId: trip.id,
        summary: `Traveler cancelled trip ${trip.id}`,
        metadata: {},
      });

      reply.send({ success: true, data: { id: trip.id, status: 'cancelled' }, code: 'TRIP_CANCELLED' });
    }
  );

  // A real delete, not a status change — only when nothing has happened on
  // this trip yet. Any offer (even one still pending, not yet accepted)
  // blocks it: accepting a pending offer later fills in the resulting
  // order's trip_id from the offer's, so deleting the trip out from under a
  // live offer would silently orphan that offer and break that order.
  // Cancel is the right tool once there's any activity at all.
  app.delete<{ Params: { id: string } }>(
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
      if (trip.traveler_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'Not your trip');
      }
      if (trip.status !== 'published') {
        throw new AppError('INVALID_STATE', 400, 'Trip is not active');
      }

      const anyOffer = await request.db
        .selectFrom('offers')
        .select(['id'])
        .where('trip_id', '=', trip.id)
        .executeTakeFirst();
      if (anyOffer) {
        throw new AppError(
          'TRIP_HAS_OFFERS',
          400,
          'This trip already has an offer on it — cancel it instead of deleting'
        );
      }

      await request.db.deleteFrom('trips').where('id', '=', trip.id).execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'trip.delete',
        targetType: 'trip',
        targetId: trip.id,
        summary: `Traveler deleted trip ${trip.id}`,
        metadata: {},
      });

      reply.send({ success: true, data: { id: trip.id }, code: 'TRIP_DELETED' });
    }
  );
}
