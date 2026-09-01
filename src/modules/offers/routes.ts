import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';

const createOfferSchema = z.object({
  request_id: z.string().uuid(),
  quoted_price: z.string().regex(/^\d+(\.\d{2})?$/),
  delivery_date: z.string().datetime(),
});

const acceptOfferSchema = z.object({
  trip_id: z.string().uuid(),
  item_description: z.string().min(1),
  quantity: z.number().positive().int(),
  unit_price: z.string().regex(/^\d+(\.\d{2})?$/),
});

export async function registerOffersRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>('/api/offers', async (request: any, reply: any) => {
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

    const offerId = generateId();
    await request.db
      .insertInto('offers')
      .values({
        id: offerId,
        traveler_id: request.userId,
        request_id: parsed.data.request_id,
        quoted_price: parsed.data.quoted_price,
        delivery_date: new Date(parsed.data.delivery_date),
        status: 'pending',
        created_at: new Date(),
        updated_at: new Date(),
      })
      .execute();

    reply.status(201).send({
      success: true,
      data: { id: offerId },
      code: 'OFFER_CREATED',
    });
  });

  app.post<{ Params: { id: string }; Body: unknown }>('/api/offers/:id/accept', async (request: any, reply: any) => {
    const parsed = acceptOfferSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'Invalid accept offer payload');
    }

    const offer = await request.db
      .selectFrom('offers')
      .selectAll()
      .where('id', '=', request.params.id)
      .executeTakeFirst();

    if (!offer) {
      throw new AppError('NOT_FOUND', 404, 'Offer not found');
    }

    const requestRow = await request.db
      .selectFrom('requests')
      .selectAll()
      .where('id', '=', offer.request_id)
      .executeTakeFirst();

    if (!requestRow) {
      throw new AppError('NOT_FOUND', 404, 'Request not found');
    }

    const trip = await request.db
      .selectFrom('trips')
      .selectAll()
      .where('id', '=', parsed.data.trip_id)
      .executeTakeFirst();

    if (!trip) {
      throw new AppError('NOT_FOUND', 404, 'Trip not found');
    }

    const shopperId = request.userId;
    if (requestRow.shopper_id !== shopperId) {
      throw new AppError('FORBIDDEN', 403, 'Only the request owner can accept the offer');
    }

    const orderId = generateId();
    const totalPrice = (Number(parsed.data.unit_price) * parsed.data.quantity).toFixed(2);
    const fees = (Number(totalPrice) * 0.08).toFixed(2);

    await request.db.transaction().execute(async (trx: any) => {
      await trx
        .updateTable('offers')
        .set({ status: 'accepted', updated_at: new Date() })
        .where('id', '=', offer.id)
        .execute();

      await trx
        .insertInto('orders')
        .values({
          id: orderId,
          shopper_id: requestRow.shopper_id,
          traveler_id: offer.traveler_id,
          trip_id: parsed.data.trip_id,
          request_id: requestRow.id,
          offer_id: offer.id,
          item_description: parsed.data.item_description,
          quantity: parsed.data.quantity,
          unit_price: parsed.data.unit_price,
          total_price: totalPrice,
          fees,
          status: 'pending_payment',
          created_at: new Date(),
          updated_at: new Date(),
        })
        .execute();
    });

    reply.send({
      success: true,
      data: { order_id: orderId, offer_id: offer.id },
      code: 'OFFER_ACCEPTED',
    });
  });
}
