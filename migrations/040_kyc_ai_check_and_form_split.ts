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
 * Two changes to the interim KYC flow from migration 039, both from the same
 * follow-up ask, in one migration since neither has shipped to real users
 * yet (safe to fold together rather than layering a third migration):
 *
 * 1. Splits the single `kyc_document_name` field into first/last name, and
 *    adds the address-on-document and contact-number fields a real ID-check
 *    form needs — modelled on a competitor's shop-verification form (name,
 *    ID number, address as printed, contact number, submitted alongside the
 *    document photo(s)).
 * 2. Adds a required selfie-with-ID photo (for a face-match check) and AI
 *    analysis columns, mirroring `orders.receipt_analysis`/`receipt_risk`
 *    (migration 014) — an AI pass cross-checks the submitted fields against
 *    what's printed on the document and whether the selfie's face matches
 *    the ID photo, advisory only, before a human still makes the final call.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (await hasColumn(db, 'users', 'kyc_document_name')) {
    await db.schema.alterTable('users').dropColumn('kyc_document_name').execute();
  }
  if (!(await hasColumn(db, 'users', 'kyc_first_name'))) {
    await db.schema.alterTable('users').addColumn('kyc_first_name', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'users', 'kyc_last_name'))) {
    await db.schema.alterTable('users').addColumn('kyc_last_name', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'users', 'kyc_address'))) {
    await db.schema.alterTable('users').addColumn('kyc_address', 'text').execute();
  }
  if (!(await hasColumn(db, 'users', 'kyc_contact_number'))) {
    await db.schema.alterTable('users').addColumn('kyc_contact_number', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'users', 'kyc_selfie_photo_url'))) {
    await db.schema.alterTable('users').addColumn('kyc_selfie_photo_url', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'users', 'kyc_ai_analysis'))) {
    await db.schema.alterTable('users').addColumn('kyc_ai_analysis', 'jsonb').execute();
  }
  if (!(await hasColumn(db, 'users', 'kyc_ai_risk'))) {
    await db.schema.alterTable('users').addColumn('kyc_ai_risk', 'varchar').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('users').dropColumn('kyc_ai_risk').execute();
  await db.schema.alterTable('users').dropColumn('kyc_ai_analysis').execute();
  await db.schema.alterTable('users').dropColumn('kyc_selfie_photo_url').execute();
  await db.schema.alterTable('users').dropColumn('kyc_contact_number').execute();
  await db.schema.alterTable('users').dropColumn('kyc_address').execute();
  await db.schema.alterTable('users').dropColumn('kyc_last_name').execute();
  await db.schema.alterTable('users').dropColumn('kyc_first_name').execute();
  await db.schema.alterTable('users').addColumn('kyc_document_name', 'varchar').execute();
}
