import { FastifyInstance } from 'fastify';
import { createRequestSchema, updateRequestSchema } from '@/types/schemas';
import { AppError, generateId } from '@/utils/helpers';
import { toUserSummary, USER_SUMMARY_COLUMNS } from '@/utils/user-summary';
import { recordAudit, actorFromRequest } from '@/services/audit';
import { recordNotification } from '@/services/notify';
import { requireCompleteProfile } from '@/utils/profile-guard';
import { config } from '@/config/env';

// Only the shopper who owns a request should ever see exactly where they
// asked for it to be delivered — every other viewer (public browse, a
// non-owner detail lookup) gets the request with these stripped, same as
// they never existed. The matched traveler only learns the address once an
// offer is accepted and it's snapshotted onto the order (see
// offers/routes.ts) — never before, and never for anyone who didn't win it.
const PRIVATE_DELIVERY_FIELDS = [
  'delivery_same_as_registered',
  'delivery_address_street',
  'delivery_address_street2',
  'delivery_address_subdistrict',
  'delivery_address_district',
  'delivery_address_postal_code',
] as const;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function redactDeliveryAddress(row: any): any {
  const copy = { ...row };
  for (const field of PRIVATE_DELIVERY_FIELDS) delete copy[field];
  return copy;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerRequestsRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>(
    '/api/requests',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request, reply) => {
      const parsed = createRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'requests.invalidRequestData');
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
          throw new AppError('NOT_FOUND', 404, 'common.tripNotFound');
        }
        if (trip.traveler_id === request.userId) {
          throw new AppError('FORBIDDEN', 403, 'requests.cannotRequestOwnTrip');
        }
        if (trip.status !== 'published' && trip.status !== 'in_progress') {
          throw new AppError('INVALID_STATUS', 409, 'requests.tripNotAcceptingRequests');
        }
        // A direct request can turn straight into an order if the traveler
        // accepts it as-is, so the shopper needs to be reachable already.
        await requireCompleteProfile(request.db, request.userId!);
        targetTrip = trip;
      }

      const requestId = generateId();
      const now = new Date();
      await request.db
        .insertInto('requests')
        .values({
          id: requestId,
          shopper_id: request.userId!,
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
          destination_country: parsed.data.destination_country,
          destination_city: parsed.data.destination_city ?? null,
          product_url: parsed.data.product_url ?? null,
          target_trip_id: targetTrip?.id ?? null,
          delivery_same_as_registered: parsed.data.delivery_same_as_registered ?? true,
          delivery_address_street: parsed.data.delivery_address_street ?? null,
          delivery_address_street2: parsed.data.delivery_address_street2 ?? null,
          delivery_address_subdistrict: parsed.data.delivery_address_subdistrict ?? null,
          delivery_address_district: parsed.data.delivery_address_district ?? null,
          delivery_address_postal_code: parsed.data.delivery_address_postal_code ?? null,
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
          params: {
            _variant: 'from_shopper',
            item: parsed.data.item_description,
            price: parsed.data.budget,
            hours: config.offerResponseTimeoutHours,
          },
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
    async (request, reply) => {
      const items = await request.db
        .selectFrom('requests')
        .selectAll()
        .where('shopper_id', '=', request.userId!)
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
    async (request, reply) => {
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
        base = base.where('shopper_id', '!=', request.userId!);
      }

      const rows = await base
        .selectAll()
        .orderBy('created_at', 'desc')
        .limit(limit)
        .offset(offset)
        .execute();
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const items = rows.map((r: any) => redactDeliveryAddress(r));

      reply.send({ success: true, data: { items, page, limit }, code: 'REQUESTS_LISTED' });
    }
  );

  app.get<{ Params: { id: string } }>(
    '/api/requests/:id',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request, reply) => {
      const itemRequest = await request.db
        .selectFrom('requests')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!itemRequest) {
        throw new AppError('NOT_FOUND', 404, 'common.requestNotFound');
      }

      // A want sent via "Request from this trip" is private between the
      // shopper and that one trip's traveler — nobody else can see it, even
      // by id (it's already excluded from every browse/feed query, and
      // offers/routes.ts enforces the same rule for offering on it). 404
      // rather than 403 so a non-party can't even confirm it exists.
      //
      // This route is in PUBLIC_GET_ROUTES (guests can view a plain want), so
      // the auth guard never resolves `request.userRole` for it — the admin
      // check has to do its own lookup rather than trusting that field here.
      if (itemRequest.target_trip_id && itemRequest.shopper_id !== request.userId) {
        const targetTrip = request.userId
          ? await request.db
              .selectFrom('trips')
              .select('traveler_id')
              .where('id', '=', itemRequest.target_trip_id)
              .executeTakeFirst()
          : undefined;
        const isTargetTraveler = Boolean(request.userId) && targetTrip?.traveler_id === request.userId;
        const isAdmin =
          !isTargetTraveler && request.userId
            ? (
                await request.db
                  .selectFrom('users')
                  .select('role')
                  .where('id', '=', request.userId)
                  .executeTakeFirst()
              )?.role === 'admin'
            : false;
        if (!isTargetTraveler && !isAdmin) {
          throw new AppError('NOT_FOUND', 404, 'common.requestNotFound');
        }
      }

      const shopper = await request.db
        .selectFrom('users')
        .select([...USER_SUMMARY_COLUMNS])
        .where('id', '=', itemRequest.shopper_id)
        .executeTakeFirst();

      // The delivery address is only ever the owning shopper's business
      // until an offer is accepted — see PRIVATE_DELIVERY_FIELDS above.
      const isOwner = itemRequest.shopper_id === request.userId;
      const responseRequest = isOwner ? itemRequest : redactDeliveryAddress(itemRequest);

      reply.send({
        success: true,
        data: { ...responseRequest, shopper: shopper ? toUserSummary(shopper) : null },
        code: 'REQUEST_FOUND',
      });
    }
  );

  app.patch<{ Params: { id: string }; Body: unknown }>(
    '/api/requests/:id',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request, reply) => {
      const itemRequest = await request.db
        .selectFrom('requests')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();
      if (!itemRequest) {
        throw new AppError('NOT_FOUND', 404, 'common.requestNotFound');
      }
      if (itemRequest.shopper_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'common.notYourWant');
      }
      if (itemRequest.status !== 'open') {
        throw new AppError('INVALID_STATE', 400, 'requests.onlyOpenCanBeEdited');
      }

      const parsed = updateRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'requests.invalidWantUpdate');
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
    async (request, reply) => {
      const itemRequest = await request.db
        .selectFrom('requests')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();
      if (!itemRequest) {
        throw new AppError('NOT_FOUND', 404, 'common.requestNotFound');
      }
      if (itemRequest.shopper_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'common.notYourWant');
      }
      if (itemRequest.status !== 'open') {
        throw new AppError('INVALID_STATE', 400, 'requests.wantNotOpen');
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
    async (request, reply) => {
      const itemRequest = await request.db
        .selectFrom('requests')
        .select(['id', 'shopper_id', 'status'])
        .where('id', '=', request.params.id)
        .executeTakeFirst();
      if (!itemRequest) {
        throw new AppError('NOT_FOUND', 404, 'common.requestNotFound');
      }
      if (itemRequest.shopper_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'common.notYourWant');
      }
      if (itemRequest.status !== 'cancelled' && itemRequest.status !== 'completed') {
        throw new AppError('INVALID_STATE', 400, 'requests.onlyCancelledOrCompletedCanBeCleared');
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
