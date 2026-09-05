import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { getReceiptAnalyzer } from '@/services/ai';
import { recordAudit } from '@/services/audit';

interface OrderForCheck {
  id: string;
  item_description: string;
  total_price: string;
  purchase_proof_url?: string | null;
  request_id?: string | null;
  created_at: Date;
}

/**
 * Run the AI receipt check for one order and persist the result. Best-effort:
 * a failure here must never affect the order (the traveller has already marked
 * it bought), so everything is wrapped and only logged.
 *
 * A `medium`/`high` result is also written to the audit log, which is what puts
 * the order in front of the operator (the review queue reads `receipt_risk`).
 */
export async function runReceiptCheck(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: Kysely<Database> | any,
  order: OrderForCheck
): Promise<void> {
  if (!order.purchase_proof_url) return;

  try {
    let sourceCountry: string | null = null;
    if (order.request_id) {
      const req = await db
        .selectFrom('requests')
        .select(['source_country'])
        .where('id', '=', order.request_id)
        .executeTakeFirst();
      sourceCountry = req?.source_country ?? null;
    }

    const analysis = await getReceiptAnalyzer().analyze({
      imageUrl: order.purchase_proof_url,
      itemDescription: order.item_description,
      expectedAmount: order.total_price,
      sourceCountry,
      orderCreatedAt: order.created_at,
    });

    await db
      .updateTable('orders')
      .set({ receipt_analysis: analysis, receipt_risk: analysis.risk, updated_at: new Date() })
      .where('id', '=', order.id)
      .execute();

    if (analysis.risk !== 'low') {
      await recordAudit(db, { id: null, role: 'system' }, {
        action: 'order.receipt_flag',
        targetType: 'order',
        targetId: order.id,
        summary: `AI receipt check flagged order ${order.id} as ${analysis.risk} risk`,
        metadata: { risk: analysis.risk, flags: analysis.flags, model: analysis.model },
      });
    }
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[receipt-check] failed for order', order.id, err);
  }
}
