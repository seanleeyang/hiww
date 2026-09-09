import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError } from '@/utils/helpers';
import { renderNotification } from '@/i18n/notifications';
import type { NotificationType } from '@/services/notify';
import { sendUploadReminders } from '@/services/upload-reminder';
import type { AppRequest } from '@/types/api';

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
        throw new AppError('AUTH_ERROR', 401, 'common.authRequired');
      }

      // Best-effort, lazy daily nudge for any of the caller's own orders
      // still waiting on an item photo + receipt — see the service doc for
      // why this lives here rather than a real cron.
      try {
        await sendUploadReminders(request.db, request.userId);
      } catch (err) {
        // eslint-disable-next-line no-console
        console.warn('[upload-reminder] failed for user', request.userId, err);
      }

      const rows = await request.db
        .selectFrom('notifications')
        .select(['id', 'type', 'subject', 'body', 'params', 'order_id', 'link', 'read_at', 'created_at'])
        .where('user_id', '=', request.userId)
        .orderBy('created_at', 'desc')
        .limit(50)
        .execute();

      const locale = (request as AppRequest).locale ?? 'en';
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const items = rows.map(({ params, ...row }: any) => {
        if (!params) return row; // pre-migration row — keep its stored (English) text.
        const { subject, body } = renderNotification(locale, row.type as NotificationType, params);
        return { ...row, subject, body };
      });

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
        throw new AppError('AUTH_ERROR', 401, 'common.authRequired');
      }
      const parsed = readSchema.safeParse(request.body ?? {});
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'notifications.invalidReadPayload');
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
