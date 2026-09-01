import { FastifyInstance } from 'fastify';
import { createOrderSchema } from '@/types/schemas';
import { AppError, generateId, calculateFees } from '@/utils/helpers';
import Decimal from 'decimal.js';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerOrdersRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>(
    '/api/orders',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = createOrderSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Invalid order data');
      }

      const orderId = generateId();
      const shopperId = request.userId!;

      // Calculate total and fees
      const unitPrice = new Decimal(parsed.data.unit_price);
      const quantity = new Decimal(parsed.data.quantity);
      const totalPrice = unitPrice.mul(quantity);
      const { total } = calculateFees(totalPrice);

      try {
        // Get traveler_id from request or trip
        let travelerId: string;
        if (parsed.data.request_id) {
          const itemRequest = await request.db
            .selectFrom('requests')
            .select('shopper_id')
            .where('id', '=', parsed.data.request_id)
            .executeTakeFirst();
          if (!itemRequest) {
            throw new AppError('NOT_FOUND', 404, 'Request not found');
          }
          // In a real app, traveler would be the one accepting the request
          travelerId = generateId();
        } else if (parsed.data.trip_id) {
          const trip = await request.db
            .selectFrom('trips')
            .select('traveler_id')
            .where('id', '=', parsed.data.trip_id)
            .executeTakeFirst();
          if (!trip) {
            throw new AppError('NOT_FOUND', 404, 'Trip not found');
          }
          travelerId = trip.traveler_id;
        } else {
          throw new AppError('VALIDATION_ERROR', 400, 'Either trip_id or request_id required');
        }

        await request.db
          .insertInto('orders')
          .values({
            id: orderId,
            shopper_id: shopperId,
            traveler_id: travelerId,
            trip_id: parsed.data.trip_id,
            request_id: parsed.data.request_id,
            item_description: parsed.data.item_description,
            quantity: parsed.data.quantity,
            unit_price: parsed.data.unit_price,
            total_price: totalPrice.toString(),
            fees: total.minus(totalPrice).toString(),
            status: 'pending_payment',
            created_at: new Date(),
            updated_at: new Date(),
          })
          .execute();

        reply.status(201).send({
          success: true,
          data: { id: orderId, total: total.toString() },
          code: 'ORDER_CREATED',
        });
      } catch (error) {
        if (error instanceof AppError) throw error;
        throw new AppError('DB_ERROR', 500, 'Failed to create order');
      }
    }
  );

  app.get<{ Params: { id: string } }>(
    '/api/orders/:id',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'Order not found');
      }

      reply.send({ success: true, data: order, code: 'ORDER_FOUND' });
    }
  );

  app.get<{ Querystring: { page?: string; limit?: string } }>(
    '/api/orders',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const page = parseInt((request.query as { page?: string }).page || '1');
      const limit = parseInt((request.query as { limit?: string }).limit || '10');
      const offset = (page - 1) * limit;

      const orders = await request.db
        .selectFrom('orders')
        .selectAll()
        .limit(limit)
        .offset(offset)
        .execute();

      const countResult = await request.db
        .selectFrom('orders')
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        .select((db: any) => [db.fn.count('id').as('count')])
        .executeTakeFirst();

      const total = countResult?.count || 0;

      reply.send({
        success: true,
        data: {
          items: orders,
          total,
          page,
          limit,
          totalPages: Math.ceil(total / limit),
        },
        code: 'ORDERS_LISTED',
      });
    }
  );
}
