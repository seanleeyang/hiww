import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';

const registerSchema = z.object({
  token: z.string().trim().min(1).max(4096),
  platform: z.enum(['android', 'web']),
});

const unregisterSchema = z.object({
  token: z.string().trim().min(1).max(4096),
});

/**
 * Device registration for push notifications (see `src/services/push/`).
 * The mobile app calls `register` whenever it obtains an FCM token —
 * on sign-in and whenever the token refreshes — and `unregister` on
 * sign-out, so a shared/logged-out device stops receiving another user's
 * pushes.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerDeviceRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>(
    '/api/devices/register',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      if (!request.userId) {
        throw new AppError('AUTH_ERROR', 401, 'common.authRequired');
      }
      const parsed = registerSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'devices.invalidRegisterPayload');
      }

      const now = new Date();
      // A token is unique per device, not per user — re-registering the
      // same device (a token refresh, or a different user signing in on
      // it) re-points the existing row rather than creating a duplicate.
      await request.db
        .insertInto('device_tokens')
        .values({
          id: generateId(),
          user_id: request.userId,
          token: parsed.data.token,
          platform: parsed.data.platform,
          created_at: now,
          updated_at: now,
        })
        .onConflict((oc: any) =>
          oc.column('token').doUpdateSet({
            user_id: request.userId,
            platform: parsed.data.platform,
            updated_at: now,
          })
        )
        .execute();

      reply.send({ success: true, data: { ok: true }, code: 'DEVICE_REGISTERED' });
    }
  );

  app.post<{ Body: unknown }>(
    '/api/devices/unregister',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      if (!request.userId) {
        throw new AppError('AUTH_ERROR', 401, 'common.authRequired');
      }
      const parsed = unregisterSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'devices.invalidUnregisterPayload');
      }

      // Scoped to the caller's own token so one signed-in user can't remove
      // another's device by guessing a token.
      await request.db
        .deleteFrom('device_tokens')
        .where('token', '=', parsed.data.token)
        .where('user_id', '=', request.userId)
        .execute();

      reply.send({ success: true, data: { ok: true }, code: 'DEVICE_UNREGISTERED' });
    }
  );
}
