import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { generateId } from '@/utils/helpers';

/**
 * Canonical notification event kinds. The mobile app switches on these for the
 * row icon; keep them stable.
 */
export type NotificationType =
  | 'offer_received'
  | 'offer_accepted'
  | 'payment_claimed'
  | 'payment_confirmed'
  | 'payment_timeout'
  | 'purchase_proof'
  | 'shipped'
  | 'delivered'
  | 'payout_sent'
  | 'dispute_opened'
  | 'dispute_resolved'
  | 'message_flagged';

export interface NotificationInput {
  userId: string;
  type: NotificationType;
  subject: string;
  body: string;
  /** Order this is about; also used to build the deep link when `link` is omitted. */
  orderId?: string | null;
  link?: string | null;
}

/**
 * Append one in-app notification. Best-effort, exactly like {@link recordAudit}:
 * a delivery failure must never break the state change that triggered it, so
 * callers `await` it but errors are swallowed with a warning.
 *
 * Pass the same `db`/`trx` the action ran on so the row commits atomically with
 * it where a transaction is in play.
 */
export async function recordNotification(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: Kysely<Database> | any,
  input: NotificationInput
): Promise<void> {
  try {
    const link = input.link ?? (input.orderId ? `/orders/${input.orderId}` : null);
    await db
      .insertInto('notifications')
      .values({
        id: generateId(),
        user_id: input.userId,
        type: input.type,
        subject: input.subject,
        body: input.body,
        order_id: input.orderId ?? null,
        link,
        created_at: new Date(),
      })
      .execute();
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[notify] failed to record', input.type, input.userId, err);
  }
}

/** Fan a single event out to several recipients. */
export async function recordNotifications(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: Kysely<Database> | any,
  inputs: NotificationInput[]
): Promise<void> {
  for (const input of inputs) {
    await recordNotification(db, input);
  }
}
