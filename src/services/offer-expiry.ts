import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { recordAudit } from '@/services/audit';
import { recordNotification } from '@/services/notify';

/**
 * Expires every offer whose current price went unanswered past
 * `respond_by` — keeps a negotiation from stalling forever. Same
 * lazy-enforcement pattern as `src/services/order-expiry.ts`: no
 * background job, just a guarded bulk UPDATE run at the top of any route
 * that reads or acts on offers.
 */
export async function expireOverdueOffers(db: Kysely<Database>): Promise<void> {
  const now = new Date();

  await db.transaction().execute(async (trx) => {
    const expired = await trx
      .updateTable('offers')
      .set({ status: 'expired', updated_at: now })
      .where('status', '=', 'pending')
      .where('respond_by', 'is not', null)
      .where('respond_by', '<', now)
      .returningAll()
      .execute();

    for (const offer of expired) {
      const requestRow = await trx
        .selectFrom('requests')
        .select(['shopper_id', 'item_description'])
        .where('id', '=', offer.request_id)
        .executeTakeFirst();
      if (!requestRow) continue;

      await recordAudit(
        trx,
        { id: null, role: 'system' },
        {
          action: 'offer.expire',
          targetType: 'offer',
          targetId: offer.id,
          summary: `Offer ${offer.id} expired — no response within the deadline`,
          metadata: { request_id: offer.request_id, quoted_price: offer.quoted_price, round: offer.round },
        }
      );

      await recordNotification(trx, {
        userId: offer.traveler_id,
        type: 'offer_expired',
        params: { _variant: 'traveler', item: requestRow.item_description },
        link: `/wants/${offer.request_id}`,
      });
      await recordNotification(trx, {
        userId: requestRow.shopper_id,
        type: 'offer_expired',
        params: { _variant: 'shopper', item: requestRow.item_description },
        link: `/wants/${offer.request_id}`,
      });
    }
  });
}
