import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import Decimal from 'decimal.js';
import { AppError, generateId } from '@/utils/helpers';
import { config } from '@/config/env';
import { recordAudit, actorFromRequest } from '@/services/audit';
import { recordNotification } from '@/services/notify';
import { requireCompleteProfile } from '@/utils/profile-guard';
import { expireOverdueOffers } from '@/services/offer-expiry';

const PLATFORM_FEE_RATE = 0.08;

const createOfferSchema = z.object({
  request_id: z.string().uuid(),
  trip_id: z.string().uuid(),
  quoted_price: z.string().regex(/^\d+(\.\d{2})?$/),
  delivery_date: z.string().datetime(),
});

const counterOfferSchema = z.object({
  quoted_price: z.string().regex(/^\d+(\.\d{2})?$/),
});

type NegotiationRole = 'traveler' | 'shopper';

/** Which side made the offer's current price, and whether the caller may
 * act on it at all. Throws if the caller isn't part of this offer. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function roleFor(offer: any, requestRow: any, userId: string): NegotiationRole {
  if (offer.traveler_id === userId) return 'traveler';
  if (requestRow.shopper_id === userId) return 'shopper';
  throw new AppError('FORBIDDEN', 403, 'You are not part of this offer');
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerOffersRoutes(app: FastifyInstance): Promise<void> {
  // Traveler makes an offer on an open request, tied to one of their trips.
  app.post<{ Body: unknown }>(
    '/api/offers',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = createOfferSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Invalid offer data');
      }

      // An accepted offer becomes an order — the traveler needs to be reachable first.
      await requireCompleteProfile(request.db, request.userId);

      const requestRow = await request.db
        .selectFrom('requests')
        .selectAll()
        .where('id', '=', parsed.data.request_id)
        .executeTakeFirst();
      if (!requestRow) {
        throw new AppError('NOT_FOUND', 404, 'Request not found');
      }
      if (requestRow.shopper_id === request.userId) {
        throw new AppError('FORBIDDEN', 403, 'You cannot make an offer on your own request');
      }
      if (requestRow.status !== 'open') {
        throw new AppError('INVALID_STATUS', 409, 'This request is no longer open');
      }

      const trip = await request.db
        .selectFrom('trips')
        .selectAll()
        .where('id', '=', parsed.data.trip_id)
        .executeTakeFirst();
      if (!trip || trip.traveler_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'That trip is not yours');
      }

      const offerId = generateId();
      const now = new Date();
      const respondBy = new Date(now.getTime() + config.offerResponseTimeoutHours * 3_600_000);
      await request.db
        .insertInto('offers')
        .values({
          id: offerId,
          traveler_id: request.userId,
          request_id: parsed.data.request_id,
          trip_id: parsed.data.trip_id,
          quoted_price: parsed.data.quoted_price,
          delivery_date: new Date(parsed.data.delivery_date),
          status: 'pending',
          round: 0,
          last_actor: 'traveler',
          respond_by: respondBy,
          // pg auto-parses jsonb on read but doesn't auto-stringify arrays on
          // write (a raw JS array gets sent as a Postgres array literal,
          // which isn't valid JSON) — stringify explicitly.
          price_history: JSON.stringify([{ by: 'traveler', price: parsed.data.quoted_price, at: now.toISOString() }]),
          created_at: now,
          updated_at: now,
        })
        .execute();

      await recordNotification(request.db, {
        userId: requestRow.shopper_id,
        type: 'offer_received',
        subject: 'New offer on your want',
        body: `A traveler offered to bring "${requestRow.item_description}" for ${parsed.data.quoted_price}. Accept, counter, or decline within ${config.offerResponseTimeoutHours}h.`,
        link: `/wants/${requestRow.id}`,
      });

      reply.status(201).send({ success: true, data: { id: offerId }, code: 'OFFER_CREATED' });
    }
  );

  // The traveler's own offers, with a summary of the request.
  app.get(
    '/api/offers/mine',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      await expireOverdueOffers(request.db);

      const items = await request.db
        .selectFrom('offers')
        .innerJoin('requests', 'requests.id', 'offers.request_id')
        .select([
          'offers.id',
          'offers.quoted_price',
          'offers.delivery_date',
          'offers.status',
          'offers.round',
          'offers.last_actor',
          'offers.respond_by',
          'offers.price_history',
          'offers.created_at',
          'offers.request_id',
          'requests.item_description as request_item',
          'requests.status as request_status',
        ])
        .where('offers.traveler_id', '=', request.userId)
        .orderBy('offers.created_at', 'desc')
        .execute();

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const enriched = items.map((o: any) => {
        const myTurn = o.status === 'pending' && o.last_actor !== 'traveler';
        return { ...o, my_turn: myTurn, can_counter: myTurn && o.round < config.maxOfferCounters };
      });

      reply.send({ success: true, data: { items: enriched }, code: 'OFFERS_MINE' });
    }
  );

  // Offers on a request. The request owner (and admin) see all offers with the
  // traveler's name; anyone else sees only their own offer.
  app.get<{ Params: { id: string } }>(
    '/api/requests/:id/offers',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      await expireOverdueOffers(request.db);

      const requestRow = await request.db
        .selectFrom('requests')
        .select(['id', 'shopper_id'])
        .where('id', '=', request.params.id)
        .executeTakeFirst();
      if (!requestRow) {
        throw new AppError('NOT_FOUND', 404, 'Request not found');
      }

      const owns = requestRow.shopper_id === request.userId || request.userRole === 'admin';

      let q = request.db
        .selectFrom('offers')
        .innerJoin('users', 'users.id', 'offers.traveler_id')
        .select([
          'offers.id',
          'offers.traveler_id',
          'offers.trip_id',
          'offers.quoted_price',
          'offers.delivery_date',
          'offers.status',
          'offers.round',
          'offers.last_actor',
          'offers.respond_by',
          'offers.price_history',
          'offers.created_at',
          'users.full_name as traveler_name',
        ])
        .where('offers.request_id', '=', requestRow.id)
        .orderBy('offers.created_at', 'asc');

      if (!owns) {
        q = q.where('offers.traveler_id', '=', request.userId);
      }

      const items = await q.execute();

      // My negotiation turn only makes sense for an actual party (shopper or
      // the traveler who owns the row) — admins browsing every offer aren't one.
      const myRole: NegotiationRole | null = owns && requestRow.shopper_id === request.userId ? 'shopper' : request.userRole === 'admin' ? null : 'traveler';
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const enriched = items.map((o: any) => {
        if (!myRole) return o;
        const myTurn = o.status === 'pending' && o.last_actor !== myRole;
        return { ...o, my_turn: myTurn, can_counter: myTurn && o.round < config.maxOfferCounters };
      });

      reply.send({ success: true, data: { items: enriched }, code: 'REQUEST_OFFERS' });
    }
  );

  // Either side accepts the offer's current price -> an order is created.
  // Whoever proposed that price (last_actor) can't be the one accepting it —
  // acceptance always comes from the other side.
  app.post<{ Params: { id: string } }>(
    '/api/offers/:id/accept',
    { config: { rateLimit: { max: config.moneyRateLimitMax, timeWindow: config.rateLimitWindow } } },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      await expireOverdueOffers(request.db);

      const offer = await request.db
        .selectFrom('offers')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();
      if (!offer) {
        throw new AppError('NOT_FOUND', 404, 'Offer not found');
      }
      if (offer.status !== 'pending') {
        throw new AppError('INVALID_STATUS', 409, 'This offer can no longer be accepted');
      }

      const requestRow = await request.db
        .selectFrom('requests')
        .selectAll()
        .where('id', '=', offer.request_id)
        .executeTakeFirst();
      if (!requestRow) {
        throw new AppError('NOT_FOUND', 404, 'Request not found');
      }

      const callerRole = roleFor(offer, requestRow, request.userId);
      if (offer.last_actor === callerRole) {
        throw new AppError('INVALID_STATUS', 409, "You made the current offer — waiting on the other side to respond");
      }
      if (requestRow.status !== 'open') {
        throw new AppError('INVALID_STATUS', 409, 'This request already has an accepted offer');
      }

      // Accepting creates the order — the shopper needs to be reachable,
      // regardless of which side clicked accept.
      await requireCompleteProfile(request.db, requestRow.shopper_id);

      const total = new Decimal(offer.quoted_price);
      const fees = total.mul(PLATFORM_FEE_RATE).toDecimalPlaces(2).toString();
      const quantity = Math.max(1, Number(requestRow.quantity ?? 1));
      // The traveler quotes one all-in price; split it back out per unit for the receipt.
      const unitPrice = total.div(quantity).toDecimalPlaces(2).toString();
      const orderId = generateId();
      const now = new Date();
      const paymentDeadlineAt = new Date(now.getTime() + config.paymentTimeoutMinutes * 60_000);

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await request.db.transaction().execute(async (trx: any) => {
        await trx.updateTable('offers').set({ status: 'accepted', updated_at: now }).where('id', '=', offer.id).execute();
        await trx
          .updateTable('offers')
          .set({ status: 'rejected', updated_at: now })
          .where('request_id', '=', requestRow.id)
          .where('id', '!=', offer.id)
          .where('status', '=', 'pending')
          .execute();
        await trx.updateTable('requests').set({ status: 'accepted', updated_at: now }).where('id', '=', requestRow.id).execute();
        await trx
          .insertInto('orders')
          .values({
            id: orderId,
            shopper_id: requestRow.shopper_id,
            traveler_id: offer.traveler_id,
            trip_id: offer.trip_id,
            request_id: requestRow.id,
            offer_id: offer.id,
            item_description: requestRow.item_description,
            quantity,
            unit_price: unitPrice,
            total_price: total.toString(),
            fees,
            status: 'pending_payment',
            payment_deadline_at: paymentDeadlineAt,
            created_at: now,
            updated_at: now,
          })
          .execute();
        await recordAudit(trx, actorFromRequest(request), {
          action: 'order.create',
          targetType: 'order',
          targetId: orderId,
          summary: `${callerRole === 'shopper' ? 'Shopper' : 'Traveler'} accepted an offer — order ${orderId} created (${total.toString()})`,
          metadata: {
            offer_id: offer.id,
            request_id: requestRow.id,
            total_price: total.toString(),
            fees,
            shopper_id: requestRow.shopper_id,
            traveler_id: offer.traveler_id,
            payment_deadline_at: paymentDeadlineAt,
            accepted_by: callerRole,
          },
        });
        // Notify whichever side didn't click accept — the other side is
        // already looking at the order screen they just created.
        if (callerRole === 'shopper') {
          await recordNotification(trx, {
            userId: offer.traveler_id,
            type: 'offer_accepted',
            subject: 'Your offer was accepted',
            body: `The shopper accepted your offer on "${requestRow.item_description}". They'll pay next — you'll get a heads-up when it's confirmed.`,
            orderId,
          });
        } else {
          await recordNotification(trx, {
            userId: requestRow.shopper_id,
            type: 'offer_accepted',
            subject: 'Your counter-offer was accepted',
            body: `The traveler accepted your price on "${requestRow.item_description}". Pay within ${config.paymentTimeoutMinutes} minutes or the order is cancelled.`,
            orderId,
          });
        }
      });

      reply.send({ success: true, data: { order_id: orderId, offer_id: offer.id }, code: 'OFFER_ACCEPTED' });
    }
  );

  // Propose a different price. Capped at config.maxOfferCounters total so a
  // negotiation resolves fast rather than dragging on — once the cap is
  // hit, the current price can only be accepted or declined, not countered
  // again. Same last_actor rule as accept: you can't counter your own
  // still-standing price.
  app.post<{ Params: { id: string }; Body: unknown }>(
    '/api/offers/:id/counter',
    { config: { rateLimit: { max: config.moneyRateLimitMax, timeWindow: config.rateLimitWindow } } },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = counterOfferSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Invalid counter-offer price');
      }

      await expireOverdueOffers(request.db);

      const offer = await request.db
        .selectFrom('offers')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();
      if (!offer) {
        throw new AppError('NOT_FOUND', 404, 'Offer not found');
      }
      if (offer.status !== 'pending') {
        throw new AppError('INVALID_STATUS', 409, 'This offer is no longer open for negotiation');
      }

      const requestRow = await request.db
        .selectFrom('requests')
        .select(['shopper_id', 'item_description', 'status'])
        .where('id', '=', offer.request_id)
        .executeTakeFirst();
      if (!requestRow) {
        throw new AppError('NOT_FOUND', 404, 'Request not found');
      }
      if (requestRow.status !== 'open') {
        throw new AppError('INVALID_STATUS', 409, 'This want is no longer open');
      }

      const callerRole = roleFor(offer, requestRow, request.userId);
      if (offer.last_actor === callerRole) {
        throw new AppError('INVALID_STATUS', 409, "You made the current offer — waiting on the other side to respond");
      }
      if (offer.round >= config.maxOfferCounters) {
        throw new AppError(
          'INVALID_STATUS',
          409,
          "You've reached the counter-offer limit — accept the current price or decline"
        );
      }

      const now = new Date();
      const respondBy = new Date(now.getTime() + config.offerResponseTimeoutHours * 3_600_000);
      const history = Array.isArray(offer.price_history) ? offer.price_history : [];
      const nextRound = offer.round + 1;

      await request.db
        .updateTable('offers')
        .set({
          quoted_price: parsed.data.quoted_price,
          round: nextRound,
          last_actor: callerRole,
          respond_by: respondBy,
          price_history: JSON.stringify([
            ...history,
            { by: callerRole, price: parsed.data.quoted_price, at: now.toISOString() },
          ]),
          updated_at: now,
        })
        .where('id', '=', offer.id)
        .execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'offer.counter',
        targetType: 'offer',
        targetId: offer.id,
        summary: `${callerRole === 'traveler' ? 'Traveler' : 'Shopper'} countered at ${parsed.data.quoted_price} (round ${nextRound})`,
        metadata: { round: nextRound, quoted_price: parsed.data.quoted_price },
      });

      const otherPartyId = callerRole === 'traveler' ? requestRow.shopper_id : offer.traveler_id;
      const canStillCounter = nextRound < config.maxOfferCounters;
      await recordNotification(request.db, {
        userId: otherPartyId,
        type: 'offer_countered',
        subject: 'New counter-offer',
        body: `${callerRole === 'traveler' ? 'The traveler' : 'The shopper'} countered at ${parsed.data.quoted_price} on "${requestRow.item_description}". ${
          canStillCounter ? `Accept, counter, or decline` : `Accept or decline`
        } within ${config.offerResponseTimeoutHours}h.`,
        link: `/wants/${offer.request_id}`,
      });

      reply.send({
        success: true,
        data: { id: offer.id, quoted_price: parsed.data.quoted_price, round: nextRound, can_counter: canStillCounter },
        code: 'OFFER_COUNTERED',
      });
    }
  );

  // Decline the offer's current price outright — no counter, negotiation
  // over. The want stays open: other travelers can still offer on it, and
  // this same traveler is free to submit a brand-new offer if they want.
  app.post<{ Params: { id: string } }>(
    '/api/offers/:id/reject',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      await expireOverdueOffers(request.db);

      const offer = await request.db
        .selectFrom('offers')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();
      if (!offer) {
        throw new AppError('NOT_FOUND', 404, 'Offer not found');
      }
      if (offer.status !== 'pending') {
        throw new AppError('INVALID_STATUS', 409, 'This offer is no longer open');
      }

      const requestRow = await request.db
        .selectFrom('requests')
        .select(['shopper_id', 'item_description'])
        .where('id', '=', offer.request_id)
        .executeTakeFirst();
      if (!requestRow) {
        throw new AppError('NOT_FOUND', 404, 'Request not found');
      }

      const callerRole = roleFor(offer, requestRow, request.userId);
      if (offer.last_actor === callerRole) {
        throw new AppError('INVALID_STATUS', 409, "You made the current offer — waiting on the other side to respond");
      }

      const now = new Date();
      await request.db.updateTable('offers').set({ status: 'rejected', updated_at: now }).where('id', '=', offer.id).execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'offer.decline',
        targetType: 'offer',
        targetId: offer.id,
        summary: `${callerRole === 'traveler' ? 'Traveler' : 'Shopper'} declined the offer`,
        metadata: { quoted_price: offer.quoted_price, round: offer.round },
      });

      const otherPartyId = callerRole === 'traveler' ? requestRow.shopper_id : offer.traveler_id;
      await recordNotification(request.db, {
        userId: otherPartyId,
        type: 'offer_declined',
        subject: 'Offer declined',
        body: `${callerRole === 'traveler' ? 'The traveler' : 'The shopper'} declined on "${requestRow.item_description}".`,
        link: `/wants/${offer.request_id}`,
      });

      reply.send({ success: true, data: { id: offer.id, status: 'rejected' }, code: 'OFFER_DECLINED' });
    }
  );
}
