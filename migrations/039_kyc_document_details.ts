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
 * KYC has always been a free-text `document_type`/`document_id` pair that
 * only ever landed in the audit log — nothing was ever persisted for an
 * admin to actually look at while reviewing. Real NDID integration needs a
 * formal RP membership with the consortium (not something wireable from
 * here), so this is the interim, still-manual path: a photo of the ID
 * document (plus an optional second page — e.g. a passport's visa stamp
 * page, or the back of a card, mirroring the two-attachment pattern
 * competitor KYC forms use) and the name as printed on the document, stored
 * on the user row so the review queue can show both alongside the account's
 * own name/email for comparison. All nullable — existing users have none of
 * this.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'users', 'kyc_document_type'))) {
    await db.schema.alterTable('users').addColumn('kyc_document_type', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'users', 'kyc_document_id'))) {
    await db.schema.alterTable('users').addColumn('kyc_document_id', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'users', 'kyc_document_name'))) {
    await db.schema.alterTable('users').addColumn('kyc_document_name', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'users', 'kyc_document_photo_url'))) {
    await db.schema.alterTable('users').addColumn('kyc_document_photo_url', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'users', 'kyc_document_photo_back_url'))) {
    await db.schema.alterTable('users').addColumn('kyc_document_photo_back_url', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'users', 'kyc_submitted_at'))) {
    await db.schema.alterTable('users').addColumn('kyc_submitted_at', 'timestamptz').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('users').dropColumn('kyc_submitted_at').execute();
  await db.schema.alterTable('users').dropColumn('kyc_document_photo_back_url').execute();
  await db.schema.alterTable('users').dropColumn('kyc_document_photo_url').execute();
  await db.schema.alterTable('users').dropColumn('kyc_document_name').execute();
  await db.schema.alterTable('users').dropColumn('kyc_document_id').execute();
  await db.schema.alterTable('users').dropColumn('kyc_document_type').execute();
}
