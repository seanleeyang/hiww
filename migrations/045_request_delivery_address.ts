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
 * A shopper's request never had anywhere to say WHERE to actually deliver
 * the item beyond a coarse destination_country/destination_city (migration
 * 027, used only for public browse/matching) — nothing street-level ever
 * flowed to whoever fulfils it. `requests` gets a "same as my registered
 * address" flag (default true) plus optional street-level fields used only
 * when it's false; both stay private to the shopper (never in the public
 * browse feed/detail — see requests/routes.ts). At accept-offer time the
 * *resolved* address (either the shopper's current profile address, or
 * these request-specific fields) is snapshotted onto `orders` — same
 * immutable-audit-trail pattern as the payout bank snapshot (migration
 * 043) — so the matched traveler has somewhere to ship to, and it can't
 * change out from under them if the shopper edits their profile afterwards.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'requests', 'delivery_same_as_registered'))) {
    await db.schema
      .alterTable('requests')
      .addColumn('delivery_same_as_registered', 'boolean', (col) => col.notNull().defaultTo(true))
      .execute();
  }
  for (const column of [
    'delivery_address_street',
    'delivery_address_street2',
    'delivery_address_subdistrict',
    'delivery_address_district',
    'delivery_address_postal_code',
  ]) {
    if (!(await hasColumn(db, 'requests', column))) {
      await db.schema.alterTable('requests').addColumn(column, 'text').execute();
    }
  }

  for (const column of [
    'delivery_address_street',
    'delivery_address_street2',
    'delivery_address_subdistrict',
    'delivery_address_district',
    'delivery_address_city',
    'delivery_address_postal_code',
    'delivery_address_country',
  ]) {
    if (!(await hasColumn(db, 'orders', column))) {
      await db.schema.alterTable('orders').addColumn(column, 'text').execute();
    }
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  for (const column of [
    'delivery_address_street',
    'delivery_address_street2',
    'delivery_address_subdistrict',
    'delivery_address_district',
    'delivery_address_city',
    'delivery_address_postal_code',
    'delivery_address_country',
  ]) {
    await db.schema.alterTable('orders').dropColumn(column).execute();
  }
  for (const column of [
    'delivery_address_street',
    'delivery_address_street2',
    'delivery_address_subdistrict',
    'delivery_address_district',
    'delivery_address_postal_code',
    'delivery_same_as_registered',
  ]) {
    await db.schema.alterTable('requests').dropColumn(column).execute();
  }
}
