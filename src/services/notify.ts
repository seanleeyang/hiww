import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { generateId } from '@/utils/helpers';
import { renderNotification } from '@/i18n/notifications';
import { sendPush } from '@/services/push-notify';

/**
 * Canonical notification event kinds. The mobile app switches on these for the
 * row icon; keep them stable.
 */
export type NotificationType =
  | 'offer_received'
  | 'offer_accepted'
  | 'offer_countered'
  | 'offer_declined'
  | 'offer_expired'
  | 'payment_claimed'
  | 'payment_confirmed'
  | 'payment_timeout'
  | 'kyc_submitted'
  | 'kyc_reviewed'
  | 'purchase_proof'
  | 'upload_reminder'
  | 'shipped'
  | 'delivered'
  | 'payout_due'
  | 'payout_sent'
  | 'dispute_opened'
  | 'dispute_resolved'
  | 'message_flagged'
  | 'order_cancelled'
  | 'refund_due'
  | 'refund_sent';

export interface NotificationInput {
  userId: string;
  type: NotificationType;
  /** Rendered into `subject`/`body` (English, for the stored columns) and
   * re-rendered per-reader locale at `GET /api/notifications` time — see
   * `src/i18n/notifications.ts`. Include `_variant` when this `type` has more
   * than one distinct wording (e.g. who the recipient is). */
  params: Record<string, string | number | boolean>;
  /** Order this is about; also used to build the deep link when `link` is omitted. */
  orderId?: string | null;
  link?: string | null;
}

/**
 * Append one in-app notification and fire a "hard" push alongside it — every
 * event that shows up in the notification feed also reaches the user's
 * device even with the app closed, without each call site having to
 * remember to wire push separately. Best-effort, exactly like
 * {@link recordAudit}: a delivery failure must never break the state change
 * that triggered it, so callers `await` it but errors are swallowed with a
 * warning.
 *
 * Pass the same `db`/`trx` the action ran on so the row commits atomically with
 * it where a transaction is in play.
 */
export async function recordNotification(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: Kysely<Database> | any,
  input: NotificationInput
): Promise<void> {
  const link = input.link ?? (input.orderId ? `/orders/${input.orderId}` : null);
  const { subject, body } = renderNotification('en', input.type, input.params);
  try {
    await db
      .insertInto('notifications')
      .values({
        id: generateId(),
        user_id: input.userId,
        type: input.type,
        subject,
        body,
        params: JSON.stringify(input.params),
        order_id: input.orderId ?? null,
        link,
        created_at: new Date(),
      })
      .execute();
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[notify] failed to record', input.type, input.userId, err);
  }

  // Push is independent of the in-app row above succeeding — a device
  // should still be alerted even if, say, the insert raced a bad state.
  await sendPush(db, input.userId, { title: subject, body, data: { link: link ?? '' } });
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
