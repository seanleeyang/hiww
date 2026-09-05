import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import Decimal from 'decimal.js';
import { AppError, generateId } from '@/utils/helpers';
import { config } from '@/config/env';
import { recordAudit, actorFromRequest } from '@/services/audit';
import { recordNotification } from '@/services/notify';

const PLATFORM_FEE_RATE = 0.08;

const createOfferSchema = z.object({
  request_id: z.string().uuid(),
  trip_id: z.string().uuid(),
  quoted_price: z.string().regex(/^\d+(\.\d{2})?$/),
  delivery_date: z.string().datetime(),
});

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
          created_at: new Date(),
          updated_at: new Date(),
        })
        .execute();

      await recordNotification(request.db, {
        userId: requestRow.shopper_id,
        type: 'offer_received',
        subject: 'New offer on your want',
        body: `A traveler offered to bring "${requestRow.item_description}" for ${parsed.data.quoted_price}. Open it to review and accept.`,
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
      const items = await request.db
        .selectFrom('offers')
        .innerJoin('requests', 'requests.id', 'offers.request_id')
        .select([
          'offers.id',
          'offers.quoted_price',
          'offers.delivery_date',
          'offers.status',
          'offers.created_at',
          'offers.request_id',
          'requests.item_description as request_item',
          'requests.status as request_status',
        ])
        .where('offers.traveler_id', '=', request.userId)
        .orderBy('offers.created_at', 'desc')
        .execute();
      reply.send({ success: true, data: { items }, code: 'OFFERS_MINE' });
    }
  );

  // Offers on a request. The request owner (and admin) see all offers with the
  // traveler's name; anyone else sees only their own offer.
  app.get<{ Params: { id: string } }>(
    '/api/requests/:id/offers',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
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
          'offers.created_at',
          'users.full_name as traveler_name',
        ])
        .where('offers.request_id', '=', requestRow.id)
        .orderBy('offers.created_at', 'asc');

      if (!owns) {
        q = q.where('offers.traveler_id', '=', request.userId);
      }

      const items = await q.execute();
      reply.send({ success: true, data: { items }, code: 'REQUEST_OFFERS' });
    }
  );

  // Shopper accepts an offer on their request -> an order is created.
  app.post<{ Params: { id: string } }>(
    '/api/offers/:id/accept',
    { config: { rateLimit: { max: config.moneyRateLimitMax, timeWindow: config.rateLimitWindow } } },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
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
      if (requestRow.shopper_id !== request.userId) {
        throw new AppError('FORBIDDEN', 403, 'Only the request owner can accept an offer');
      }
      if (requestRow.status !== 'open') {
        throw new AppError('INVALID_STATUS', 409, 'This request already has an accepted offer');
      }

      const total = new Decimal(offer.quoted_price);
      const fees = total.mul(PLATFORM_FEE_RATE).toDecimalPlaces(2).toString();
      const quantity = Math.max(1, Number(requestRow.quantity ?? 1));
      // The traveler quotes one all-in price; split it back out per unit for the receipt.
      const unitPrice = total.div(quantity).toDecimalPlaces(2).toString();
      const orderId = generateId();
      const now = new Date();

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
            created_at: now,
            updated_at: now,
          })
          .execute();
        await recordAudit(trx, actorFromRequest(request), {
          action: 'order.create',
          targetType: 'order',
          targetId: orderId,
          summary: `Shopper accepted an offer — order ${orderId} created (${total.toString()})`,
          metadata: {
            offer_id: offer.id,
            request_id: requestRow.id,
            total_price: total.toString(),
            fees,
            shopper_id: requestRow.shopper_id,
            traveler_id: offer.traveler_id,
          },
        });
        await recordNotification(trx, {
          userId: offer.traveler_id,
          type: 'offer_accepted',
          subject: 'Your offer was accepted',
          body: `The shopper accepted your offer on "${requestRow.item_description}". They'll pay next — you'll get a heads-up when it's confirmed.`,
          orderId,
        });
      });

      reply.send({ success: true, data: { order_id: orderId, offer_id: offer.id }, code: 'OFFER_ACCEPTED' });
    }
  );
}
