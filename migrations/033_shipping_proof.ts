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
 * Optional proof the traveler shipped the item — a photo of it with the
 * courier (e.g. handed to a GrabBike rider) or a screenshot of the delivery
 * app's booking page. Unlike the purchase receipt this doesn't gate the
 * status transition; "mark shipped" still works without it.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'orders', 'shipping_proof_url'))) {
    await db.schema.alterTable('orders').addColumn('shipping_proof_url', 'text').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('orders').dropColumn('shipping_proof_url').execute();
}
