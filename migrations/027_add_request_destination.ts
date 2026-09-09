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
 * A want's "Buy in" location (`source_country`/`source_city`) already existed;
 * this adds its delivery-destination counterpart plus an optional product
 * link, for the Create Order flow. All three are nullable at the DB level
 * (existing rows have none) — `destination_country` is enforced required at
 * request-create time via Zod instead, same pattern as other presentation
 * fields added after the original schema.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'requests', 'destination_country'))) {
    await db.schema.alterTable('requests').addColumn('destination_country', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'requests', 'destination_city'))) {
    await db.schema.alterTable('requests').addColumn('destination_city', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'requests', 'product_url'))) {
    await db.schema.alterTable('requests').addColumn('product_url', 'varchar').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('requests').dropColumn('product_url').execute();
  await db.schema.alterTable('requests').dropColumn('destination_city').execute();
  await db.schema.alterTable('requests').dropColumn('destination_country').execute();
}
