import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { recordNotification } from '@/services/notify';

/** Re-fire at most about once a day — a little under 24h so a traveler who
 * opens the app at roughly the same time each day doesn't skip a day. */
const REMINDER_INTERVAL_MS = 20 * 60 * 60 * 1000;

/**
 * Nudges a traveler who has confirmed payment but hasn't yet uploaded the
 * item photo + receipt, counting down to their trip's return date. There is
 * no background scheduler in this pilot, so this runs lazily — called from
 * routes the traveler's own client already polls regularly (their
 * notification feed, their order list) rather than a true cron. A reminder
 * can arrive a little later than exactly 24h if they don't open the app,
 * but never more than about once a day while they do.
 *
 * Scoped to one traveler at a time (`travelerId`) so this stays a cheap,
 * per-request check rather than a platform-wide scan.
 */
export async function sendUploadReminders(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: Kysely<Database> | any,
  travelerId: string
): Promise<void> {
  const cutoff = new Date(Date.now() - REMINDER_INTERVAL_MS);

  const due = await db
    .selectFrom('orders')
    .innerJoin('trips', 'trips.id', 'orders.trip_id')
    .select([
      'orders.id',
      'orders.item_description',
      'trips.return_date',
    ])
    .where('orders.traveler_id', '=', travelerId)
    .where('orders.status', '=', 'confirmed')
    .where((eb: any) =>
      eb.or([
        eb('orders.last_upload_reminder_at', 'is', null),
        eb('orders.last_upload_reminder_at', '<', cutoff),
      ])
    )
    .execute();

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  for (const order of due as any[]) {
    if (!order.return_date) continue; // no trip linked — nothing to count down to

    const daysLeft = Math.max(
      0,
      Math.ceil((new Date(order.return_date).getTime() - Date.now()) / 86_400_000)
    );

    await recordNotification(db, {
      userId: travelerId,
      type: 'upload_reminder',
      params: { item: order.item_description, days: daysLeft },
      orderId: order.id,
    });

    await db
      .updateTable('orders')
      .set({ last_upload_reminder_at: new Date() })
      .where('id', '=', order.id)
      .execute();
  }
}
