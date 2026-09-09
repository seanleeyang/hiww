import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { getPushSender } from '@/services/push';
import type { PushMessage } from '@/services/push/types';

/**
 * Sends a "hard" push to every device registered for this user (see
 * `src/modules/devices/routes.ts`), pruning any token the provider reports
 * as dead. Best-effort exactly like `recordNotification` — a push failure
 * must never break the caller's own action (the order was already accepted/
 * created regardless of whether the shopper gets alerted about it).
 */
export async function sendPush(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: Kysely<Database> | any,
  userId: string,
  message: PushMessage
): Promise<void> {
  try {
    const devices = await db
      .selectFrom('device_tokens')
      .select(['token'])
      .where('user_id', '=', userId)
      .execute();
    if (!devices.length) return;

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const tokens = devices.map((d: any) => d.token as string);
    const { deadTokens } = await getPushSender().send(tokens, message);

    if (deadTokens.length) {
      await db.deleteFrom('device_tokens').where('token', 'in', deadTokens).execute();
    }
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[push] failed to send to user', userId, err);
  }
}
