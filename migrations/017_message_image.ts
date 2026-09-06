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
 * Order chat can now carry a photo alongside (or instead of) text. See
 * `src/services/qr-check.ts` — a photo containing a QR code never gets this
 * column populated at all (the QR is a reliable enough leakage signal that
 * it's rejected outright, not just flagged); the raw URL only ever lands in
 * the audit log for an operator to review.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'messages', 'image_url'))) {
    await db.schema.alterTable('messages').addColumn('image_url', 'text').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('messages').dropColumn('image_url').execute();
}
