import { FastifyInstance } from 'fastify';
import { AppError, generateId } from '@/utils/helpers';
import { messageSchema } from '@/types/schemas';
import { toUserSummary, USER_SUMMARY_COLUMNS } from '@/utils/user-summary';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function loadOrderForParticipant(request: any, orderId: string): Promise<any> {
  const order = await request.db
    .selectFrom('orders')
    .selectAll()
    .where('id', '=', orderId)
    .executeTakeFirst();

  if (!order) {
    throw new AppError('NOT_FOUND', 404, 'Order not found');
  }
  if (order.shopper_id !== request.userId && order.traveler_id !== request.userId) {
    throw new AppError('FORBIDDEN', 403, 'You are not part of this order');
  }
  return order;
}

/**
 * Order-scoped messaging. A conversation is every message with the same
 * `order_id`; the inbox groups by order. Poll-based — no websockets in the pilot.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerMessagesRoutes(app: FastifyInstance): Promise<void> {
  app.get<{ Params: { id: string } }>(
    '/api/orders/:id/messages',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      await loadOrderForParticipant(request, request.params.id);

      const items = await request.db
        .selectFrom('messages')
        .innerJoin('users as sender', 'sender.id', 'messages.sender_id')
        .select([
          'messages.id',
          'messages.sender_id',
          'messages.body',
          'messages.created_at',
          'messages.read_at',
          'sender.full_name as sender_name',
        ])
        .where('messages.order_id', '=', request.params.id)
        .orderBy('messages.created_at', 'asc')
        .execute();

      reply.send({ success: true, data: { items }, code: 'MESSAGES_LISTED' });
    }
  );

  app.post<{ Params: { id: string }; Body: unknown }>(
    '/api/orders/:id/messages',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = messageSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Message body is required');
      }
      await loadOrderForParticipant(request, request.params.id);

      const id = generateId();
      await request.db
        .insertInto('messages')
        .values({
          id,
          order_id: request.params.id,
          sender_id: request.userId,
          body: parsed.data.body,
          created_at: new Date(),
        })
        .execute();

      reply.status(201).send({ success: true, data: { id }, code: 'MESSAGE_SENT' });
    }
  );

  app.post<{ Params: { id: string } }>(
    '/api/orders/:id/messages/read',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      await loadOrderForParticipant(request, request.params.id);

      await request.db
        .updateTable('messages')
        .set({ read_at: new Date() })
        .where('order_id', '=', request.params.id)
        .where('sender_id', '!=', request.userId)
        .where('read_at', 'is', null)
        .execute();

      reply.send({ success: true, data: { ok: true }, code: 'MESSAGES_READ' });
    }
  );

  // Every order the caller is in that has at least one message.
  app.get(
    '/api/inbox',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const orders = await request.db
        .selectFrom('orders')
        .select(['id', 'shopper_id', 'traveler_id', 'item_description', 'status'])
        .where((eb: any) =>
          eb.or([eb('shopper_id', '=', request.userId), eb('traveler_id', '=', request.userId)])
        )
        .execute();

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const threads: any[] = [];
      for (const order of orders) {
        const last = await request.db
          .selectFrom('messages')
          .select(['id', 'sender_id', 'body', 'created_at'])
          .where('order_id', '=', order.id)
          .orderBy('created_at', 'desc')
          .limit(1)
          .executeTakeFirst();
        if (!last) continue;

        const unread = await request.db
          .selectFrom('messages')
          .select((eb: any) => eb.fn.count('id').as('count'))
          .where('order_id', '=', order.id)
          .where('sender_id', '!=', request.userId)
          .where('read_at', 'is', null)
          .executeTakeFirst();

        const counterpartyId =
          order.shopper_id === request.userId ? order.traveler_id : order.shopper_id;
        const counterparty = await request.db
          .selectFrom('users')
          .select([...USER_SUMMARY_COLUMNS])
          .where('id', '=', counterpartyId)
          .executeTakeFirst();

        threads.push({
          order_id: order.id,
          item_description: order.item_description,
          order_status: order.status,
          counterparty: counterparty ? toUserSummary(counterparty) : null,
          last_message: last,
          unread_count: Number(unread?.count ?? 0),
        });
      }

      threads.sort(
        (a, b) =>
          new Date(b.last_message.created_at).getTime() -
          new Date(a.last_message.created_at).getTime()
      );

      reply.send({ success: true, data: { items: threads }, code: 'INBOX' });
    }
  );
}
