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
 * Expands the account profile into a real "Personal Information" section
 * (gender, date of birth, and a fuller address shape — street line 2,
 * district, sub-district, alongside the existing street/city/postal/
 * country) and simplifies KYC now that Personal Information covers some of
 * what it used to ask for separately:
 *  - `kyc_contact_number` dropped — the account's own `phone` covers it,
 *    and phone changes now go through their own re-verification flow.
 *  - `kyc_document_photo_back_url` dropped — a second document page/back
 *    of card isn't asked for any more (Thai law doesn't require or
 *    generally allow photographing the back of a national ID card).
 * `kyc_document_type` stays a free `varchar` (no DB-level enum/check
 * constraint to update) — `drivers_license` is simply no longer offered by
 * the app; existing values, if any, are left as-is rather than migrated.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'users', 'gender'))) {
    await db.schema.alterTable('users').addColumn('gender', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'users', 'date_of_birth'))) {
    await db.schema.alterTable('users').addColumn('date_of_birth', 'date').execute();
  }
  if (!(await hasColumn(db, 'users', 'address_street2'))) {
    await db.schema.alterTable('users').addColumn('address_street2', 'text').execute();
  }
  if (!(await hasColumn(db, 'users', 'address_district'))) {
    await db.schema.alterTable('users').addColumn('address_district', 'text').execute();
  }
  if (!(await hasColumn(db, 'users', 'address_subdistrict'))) {
    await db.schema.alterTable('users').addColumn('address_subdistrict', 'text').execute();
  }
  if (await hasColumn(db, 'users', 'kyc_contact_number')) {
    await db.schema.alterTable('users').dropColumn('kyc_contact_number').execute();
  }
  if (await hasColumn(db, 'users', 'kyc_document_photo_back_url')) {
    await db.schema.alterTable('users').dropColumn('kyc_document_photo_back_url').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('users').addColumn('kyc_document_photo_back_url', 'varchar').execute();
  await db.schema.alterTable('users').addColumn('kyc_contact_number', 'varchar').execute();
  await db.schema.alterTable('users').dropColumn('address_subdistrict').execute();
  await db.schema.alterTable('users').dropColumn('address_district').execute();
  await db.schema.alterTable('users').dropColumn('address_street2').execute();
  await db.schema.alterTable('users').dropColumn('date_of_birth').execute();
  await db.schema.alterTable('users').dropColumn('gender').execute();
}
