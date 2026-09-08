import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { recordAudit } from '@/services/audit';
import { recordNotification } from '@/services/notify';

/**
 * Cancels every order still `pending_payment` past its `payment_deadline_at`
 * — a shopper who never pays would otherwise leave the order (and the
 * traveler's offer, and the shopper's want) stuck open forever. Reopens the
 * want so other travelers can offer on it again, and marks the accepted
 * offer `expired` rather than leaving it looking `accepted`.
 *
 * There is no background job in this app (a single Render web service), so
 * this is called lazily at the top of every route that reads or acts on
 * orders — cheap in practice since the guarded UPDATE only ever matches
 * orders that are both overdue AND still unprocessed.
 */
export async function expireOverduePayments(db: Kysely<Database>): Promise<void> {
  const now = new Date();

  await db.transaction().execute(async (trx) => {
    // The WHERE clause is the concurrency guard: once one caller's UPDATE
    // commits, the row's status is no longer 'pending_payment', so a
    // concurrent call's UPDATE simply won't match it a second time.
    const expired = await trx
      .updateTable('orders')
      .set({ status: 'cancelled', cancelled_at: now, updated_at: now })
      .where('status', '=', 'pending_payment')
      .where('payment_claimed_at', 'is', null)
      .where('payment_deadline_at', 'is not', null)
      .where('payment_deadline_at', '<', now)
      .returningAll()
      .execute();

    for (const order of expired) {
      if (order.request_id) {
        await trx
          .updateTable('requests')
          .set({ status: 'open', updated_at: now })
          .where('id', '=', order.request_id)
          .where('status', '=', 'accepted')
          .execute();
      }
      if (order.offer_id) {
        await trx
          .updateTable('offers')
          .set({ status: 'expired', updated_at: now })
          .where('id', '=', order.offer_id)
          .execute();
      }

      await recordAudit(
        trx,
        { id: null, role: 'system' },
        {
          action: 'order.payment_timeout',
          targetType: 'order',
          targetId: order.id,
          summary: `Order ${order.id} auto-cancelled — payment was not made within the deadline`,
          metadata: {
            total_price: order.total_price,
            shopper_id: order.shopper_id,
            traveler_id: order.traveler_id,
            payment_deadline_at: order.payment_deadline_at,
          },
        }
      );

      await recordNotification(trx, {
        userId: order.shopper_id,
        type: 'payment_timeout',
        params: { _variant: 'shopper', item: order.item_description },
        orderId: order.id,
      });
      await recordNotification(trx, {
        userId: order.traveler_id,
        type: 'payment_timeout',
        params: { _variant: 'traveler', item: order.item_description },
        orderId: order.id,
      });
    }
  });
}
