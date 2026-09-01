import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';

const notificationSchema = z.object({
  type: z.enum(['email', 'sms', 'push']),
  subject: z.string().min(1),
  body: z.string().min(1),
});

export async function registerNotificationsRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>('/api/notifications', async (request: any, reply: any) => {
    const parsed = notificationSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'Invalid notification payload');
    }

    const userId = request.userId;
    if (!userId) {
      throw new AppError('AUTH_ERROR', 401, 'Authentication required');
    }

    const notificationId = generateId();

    await request.db
      .insertInto('notifications')
      .values({
        id: notificationId,
        user_id: userId,
        type: parsed.data.type,
        subject: parsed.data.subject,
        body: parsed.data.body,
        created_at: new Date(),
      })
      .execute();

    reply.status(201).send({
      success: true,
      data: { id: notificationId },
      code: 'NOTIFICATION_CREATED',
    });
  });

  app.get<{ Params: { userId: string } }>('/api/notifications/:userId', async (request: any, reply: any) => {
    const user = await request.db
      .selectFrom('users')
      .select('id')
      .where('id', '=', request.params.userId)
      .executeTakeFirst();

    if (!user) {
      throw new AppError('NOT_FOUND', 404, 'User not found');
    }

    const items = await request.db
      .selectFrom('notifications')
      .selectAll()
      .where('user_id', '=', user.id)
      .orderBy('created_at', 'desc')
      .execute();

    reply.send({
      success: true,
      data: items,
      code: 'NOTIFICATIONS_LISTED',
    });
  });
}
