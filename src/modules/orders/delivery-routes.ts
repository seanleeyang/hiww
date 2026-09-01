import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';

const deliverSchema = z.object({
  note: z.string().min(1).optional(),
});

const releaseSchema = z.object({
  note: z.string().min(1).optional(),
});

export async function registerDeliveryRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Params: { id: string }; Body: unknown }>('/api/orders/:id/deliver', async (request: any, reply: any) => {
    const parsed = deliverSchema.safeParse(request.body || {});
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'Invalid delivery payload');
    }

    const order = await request.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', request.params.id)
      .executeTakeFirst();

    if (!order) {
      throw new AppError('NOT_FOUND', 404, 'Order not found');
    }

    if (order.traveler_id !== request.userId) {
      throw new AppError('FORBIDDEN', 403, 'Only the traveler can mark an order delivered');
    }

    if (order.status !== 'confirmed') {
      throw new AppError('INVALID_STATUS', 409, 'Order must be confirmed before delivery');
    }

    await request.db
      .updateTable('orders')
      .set({ status: 'in_transit', updated_at: new Date() })
      .where('id', '=', order.id)
      .execute();

    reply.send({
      success: true,
      data: { order_id: order.id, status: 'in_transit' },
      code: 'ORDER_MARKED_DELIVERED',
    });
  });

  app.post<{ Params: { id: string }; Body: unknown }>('/api/orders/:id/release', async (request: any, reply: any) => {
    const parsed = releaseSchema.safeParse(request.body || {});
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'Invalid release payload');
    }

    const order = await request.db
      .selectFrom('orders')
      .selectAll()
      .where('id', '=', request.params.id)
      .executeTakeFirst();

    if (!order) {
      throw new AppError('NOT_FOUND', 404, 'Order not found');
    }

    if (order.shopper_id !== request.userId) {
      throw new AppError('FORBIDDEN', 403, 'Only the shopper can release funds');
    }

    if (order.status !== 'in_transit') {
      throw new AppError('INVALID_STATUS', 409, 'Order must be in transit before release');
    }

    const now = new Date();
    const total = Number(order.total_price);

    await request.db.transaction().execute(async (trx: any) => {
      await trx
        .updateTable('orders')
        .set({ status: 'delivered', updated_at: now })
        .where('id', '=', order.id)
        .execute();

      const travelerBalanceEntry = await trx
        .selectFrom('ledger_entries')
        .select('balance_after')
        .where('user_id', '=', order.traveler_id)
        .orderBy('created_at', 'desc')
        .limit(1)
        .executeTakeFirst();

      const travelerBalance = travelerBalanceEntry ? Number(travelerBalanceEntry.balance_after) : 0;

      await trx
        .insertInto('ledger_entries')
        .values({
          id: generateId(),
          user_id: order.traveler_id,
          order_id: order.id,
          entry_type: 'credit',
          amount: total.toString(),
          balance_after: (travelerBalance + total).toString(),
          description: `Funds released for completed order ${order.id}`,
          created_at: now,
        })
        .execute();
    });

    reply.send({
      success: true,
      data: { order_id: order.id, status: 'delivered' },
      code: 'ORDER_RELEASED',
    });
  });
}
