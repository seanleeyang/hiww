import { Kysely, sql } from 'kysely';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function hasColumn(db: Kysely<any>, table: string, column: string): Promise<boolean> {
  const result = await sql<{ exists: boolean }>`
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = ${table} AND column_name = ${column}
    ) AS exists
  `.execute(db);
  return result.rows[0]?.exists ?? false;
}

/**
 * A shopper who never pays would otherwise leave an order stuck in
 * `pending_payment` forever. `payment_deadline_at` is set at order creation
 * (accept-offer) to now + PAYMENT_TIMEOUT_MINUTES; `cancelled_at` records
 * when an order — for this reason or any future one — actually cancelled.
 * There is no background job in this app, so the deadline is enforced
 * lazily: see `src/services/order-expiry.ts`.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'orders', 'payment_deadline_at'))) {
    await db.schema.alterTable('orders').addColumn('payment_deadline_at', 'timestamp').execute();
  }
  if (!(await hasColumn(db, 'orders', 'cancelled_at'))) {
    await db.schema.alterTable('orders').addColumn('cancelled_at', 'timestamp').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('orders').dropColumn('payment_deadline_at').execute();
  await db.schema.alterTable('orders').dropColumn('cancelled_at').execute();
}
