import { FastifyInstance } from 'fastify';
import { createRequestSchema, updateRequestSchema } from '@/types/schemas';
import { AppError, generateId } from '@/utils/helpers';
import { toUserSummary, USER_SUMMARY_COLUMNS } from '@/utils/user-summary';
import { recordAudit, actorFromRequest } from '@/services/audit';
import { recordNotification } from '@/services/notify';
import { requireCompleteProfile } from '@/utils/profile-guard';
import { config } from '@/config/env';

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

      // "Request from this trip": validate the target up front so we don't
      // create an orphaned want if it turns out to be invalid.
      let targetTrip: { id: string; traveler_id: string; return_date: Date } | undefined;
      if (parsed.data.target_trip_id) {
        const trip = await request.db
          .selectFrom('trips')
          .select(['id', 'traveler_id', 'status', 'return_date'])
          .where('id', '=', parsed.data.target_trip_id)
          .executeTakeFirst();
        if (!trip) {
          throw new AppError('NOT_FOUND', 404, 'Trip not found');
        }
        if (trip.traveler_id === request.userId) {
          throw new AppError('FORBIDDEN', 403, 'You cannot request from your own trip');
        }
        if (trip.status !== 'published' && trip.status !== 'in_progress') {
          throw new AppError('INVALID_STATUS', 409, 'This trip is no longer accepting requests');
        }
        // A direct request can turn straight into an order if the traveler
        // accepts it as-is, so the shopper needs to be reachable already.
        await requireCompleteProfile(request.db, request.userId);
        targetTrip = trip;
      }

      const requestId = generateId();
      const now = new Date();
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
          target_trip_id: targetTrip?.id ?? null,
          status: 'open',
          created_at: now,
          updated_at: now,
        })
        .execute();

      let offerId: string | undefined;
      if (targetTrip) {
        // The shopper's stated budget is their opening price in a
        // negotiation with that trip's traveler — same mechanics as a
        // traveler-initiated offer (see offers/routes.ts), just started
        // from the other side. Nobody else can see or offer on this want
        // (excluded from GET /api/requests) so this is the only way in.
        offerId = generateId();
        const respondBy = new Date(now.getTime() + config.offerResponseTimeoutHours * 3_600_000);
        await request.db
          .insertInto('offers')
          .values({
            id: offerId,
            traveler_id: targetTrip.traveler_id,
            request_id: requestId,
            trip_id: targetTrip.id,
            quoted_price: parsed.data.budget,
            delivery_date: targetTrip.return_date,
            status: 'pending',
            round: 0,
            last_actor: 'shopper',
            respond_by: respondBy,
            price_history: JSON.stringify([{ by: 'shopper', price: parsed.data.budget, at: now.toISOString() }]),
            created_at: now,
            updated_at: now,
          })
          .execute();

        await recordNotification(request.db, {
          userId: targetTrip.traveler_id,
          type: 'offer_received',
          subject: 'Someone requested an item from your trip',
          body: `A shopper wants "${parsed.data.item_description}" from your trip for ${parsed.data.budget}. Accept, counter, or decline within ${config.offerResponseTimeoutHours}h.`,
          link: `/wants/${requestId}`,
        });
      }

      reply.status(201).send({
        success: true,
        data: { id: requestId, ...(offerId ? { offer_id: offerId } : {}) },
        code: 'REQUEST_CREATED',
      });
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
        .where('archived_at', 'is', null)
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

      // Requests sent directly to one trip ("Request from this trip") are
      // private between that shopper and traveler — never in public browse.
      let base = request.db
        .selectFrom('requests')
        .where('status', '=', 'open')
        .where('target_trip_id', 'is', null);
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

  // Clears a want from the owner's own My Wants list — doesn't touch the
  // row, any offer/order tied to it, or its audit history, just hides it
  // from `GET /api/requests/mine`. Only for wants that are already done
  // with (cancelled/completed) — anything still open should be cancelled
  // first.
  app.post<{ Params: { id: string } }>(
    '/api/requests/:id/archive',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const itemRequest = await request.db
        .selectFrom('requests')
        .select(['id', 'shopper_id', 'status'])
        .where('id', '=', request.params.id)
        .executeTakeFirst();
      if (!itemRequest) {
        throw new AppError('NOT_FOUND', 404, 'Request not found');
      }
      if (itemRequest.shopper_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'Not your want');
      }
      if (itemRequest.status !== 'cancelled' && itemRequest.status !== 'completed') {
        throw new AppError('INVALID_STATE', 400, 'Only a cancelled or completed want can be cleared from your list');
      }

      await request.db
        .updateTable('requests')
        .set({ archived_at: new Date(), updated_at: new Date() })
        .where('id', '=', itemRequest.id)
        .execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'request.archive',
        targetType: 'request',
        targetId: itemRequest.id,
        summary: `Shopper cleared want ${itemRequest.id} from their list`,
        metadata: {},
      });

      reply.send({ success: true, data: { id: itemRequest.id }, code: 'REQUEST_ARCHIVED' });
    }
  );
}
