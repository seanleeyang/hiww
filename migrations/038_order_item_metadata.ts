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
 * `requests` has had `title` and `product_url` since migration 007/027, but
 * `orders` never copied them over — only `item_description` was carried
 * across at accept-offer time. This left the product name and any reference
 * link missing from the order screen at every post-negotiation stage
 * (payment, purchased, shipped, delivered), even though they were already
 * visible on the want itself. Both nullable: existing orders never had a
 * source `title`/`product_url` to backfill from.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'orders', 'title'))) {
    await db.schema.alterTable('orders').addColumn('title', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'orders', 'product_url'))) {
    await db.schema.alterTable('orders').addColumn('product_url', 'varchar').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('orders').dropColumn('product_url').execute();
  await db.schema.alterTable('orders').dropColumn('title').execute();
}
