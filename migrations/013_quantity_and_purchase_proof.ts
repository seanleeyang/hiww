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
 * Two additions:
 *
 *  - `requests.quantity` — a want can ask for more than one of an item. Flows
 *    through to `orders.quantity` when the offer is accepted.
 *  - `orders.purchase_proof_url` / `orders.purchased_at` — the traveler uploads
 *    a photo of the shop receipt after buying, which unlocks the "mark shipped"
 *    step. Proof that the genuine item was bought, and evidence if the shopper
 *    later disputes it as fake.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'requests', 'quantity'))) {
    await db.schema
      .alterTable('requests')
      .addColumn('quantity', 'integer', (col) => col.notNull().defaultTo(1))
      .execute();
  }

  if (!(await hasColumn(db, 'orders', 'purchase_proof_url'))) {
    await db.schema.alterTable('orders').addColumn('purchase_proof_url', 'text').execute();
  }

  if (!(await hasColumn(db, 'orders', 'purchased_at'))) {
    await db.schema.alterTable('orders').addColumn('purchased_at', 'timestamptz').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('orders').dropColumn('purchased_at').execute();
  await db.schema.alterTable('orders').dropColumn('purchase_proof_url').execute();
  await db.schema.alterTable('requests').dropColumn('quantity').execute();
}
