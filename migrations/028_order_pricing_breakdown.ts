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
 * The MVP pricing model (`src/services/pricing.ts`) adds a traveller reward
 * on top of the item price, paid by the shopper alongside the existing
 * service fee — so `orders.total_price` (goods price) and `orders.fees`
 * (platform's cut) keep their existing meaning and columns; only the new
 * split needs new columns. Nullable and never backfilled: existing orders
 * were priced under the old flat-8%-fee model and must keep exactly the
 * numbers they were created with, not be recomputed under the new formula.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  for (const column of ['traveller_reward', 'shopper_total', 'traveller_payout', 'currency']) {
    if (!(await hasColumn(db, 'orders', column))) {
      await db.schema.alterTable('orders').addColumn(column, 'varchar').execute();
    }
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('orders').dropColumn('currency').execute();
  await db.schema.alterTable('orders').dropColumn('traveller_payout').execute();
  await db.schema.alterTable('orders').dropColumn('shopper_total').execute();
  await db.schema.alterTable('orders').dropColumn('traveller_reward').execute();
}
