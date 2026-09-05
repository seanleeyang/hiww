import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError } from '@/utils/helpers';

const readSchema = z.object({
  // Omit to mark everything read; pass an id to mark just that one.
  id: z.string().uuid().optional(),
});

/**
 * In-app notification feed for the signed-in user. Rows are written by
 * `recordNotification()` at each order state change (see `src/services/notify.ts`).
 * Poll-based, like the inbox — no websockets in the pilot.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerNotificationsRoutes(app: FastifyInstance): Promise<void> {
  // The caller's notifications, newest first, plus the unread count so the app
  // can render the bell badge from one request.
  app.get(
    '/api/notifications',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      if (!request.userId) {
        throw new AppError('AUTH_ERROR', 401, 'Authentication required');
      }

      const items = await request.db
        .selectFrom('notifications')
        .select(['id', 'type', 'subject', 'body', 'order_id', 'link', 'read_at', 'created_at'])
        .where('user_id', '=', request.userId)
        .orderBy('created_at', 'desc')
        .limit(50)
        .execute();

      const unread = await request.db
        .selectFrom('notifications')
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        .select((eb: any) => eb.fn.count('id').as('count'))
        .where('user_id', '=', request.userId)
        .where('read_at', 'is', null)
        .executeTakeFirst();

      reply.send({
        success: true,
        data: { items, unread_count: Number(unread?.count ?? 0) },
        code: 'NOTIFICATIONS_LISTED',
      });
    }
  );

  // Mark one (by id) or all of the caller's notifications as read.
  app.post<{ Body: unknown }>(
    '/api/notifications/read',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      if (!request.userId) {
        throw new AppError('AUTH_ERROR', 401, 'Authentication required');
      }
      const parsed = readSchema.safeParse(request.body ?? {});
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Invalid read payload');
      }

      let q = request.db
        .updateTable('notifications')
        .set({ read_at: new Date() })
        .where('user_id', '=', request.userId)
        .where('read_at', 'is', null);
      if (parsed.data.id) {
        q = q.where('id', '=', parsed.data.id);
      }
      await q.execute();

      reply.send({ success: true, data: { ok: true }, code: 'NOTIFICATIONS_READ' });
    }
  );
}
