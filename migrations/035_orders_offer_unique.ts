import { Kysely, sql } from 'kysely';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function hasIndex(db: Kysely<any>, name: string): Promise<boolean> {
  const result = await sql<{ exists: boolean }>`
    SELECT EXISTS (
      SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = ${name}
    ) AS exists
  `.execute(db);
  return result.rows[0]?.exists ?? false;
}

/**
 * Defense-in-depth for the offer-accept race fixed alongside this migration
 * (src/modules/offers/routes.ts) — a unique index on orders.offer_id makes a
 * duplicate order for the same offer impossible at the database level even if
 * the application-level guard is ever bypassed. NULLs (orders not created via
 * offer-accept, if any ever exist) are unaffected — Postgres treats each NULL
 * as distinct for uniqueness purposes.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasIndex(db, 'orders_offer_id_unique'))) {
    await db.schema
      .createIndex('orders_offer_id_unique')
      .on('orders')
      .column('offer_id')
      .unique()
      .execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropIndex('orders_offer_id_unique').execute();
}
