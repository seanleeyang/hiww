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
 * Output of the AI chat moderation check (see `src/services/chat-moderation.ts`).
 * A message is flagged either by the instant regex pass (contact-info /
 * off-platform-payment leakage) or the background AI pass (subtler leakage,
 * harassment). `flag_reviewed_at` is set once an operator has looked at a
 * flagged message and cleared it from the review queue.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'messages', 'flag_risk'))) {
    await db.schema.alterTable('messages').addColumn('flag_risk', 'text').execute();
  }
  if (!(await hasColumn(db, 'messages', 'flag_reasons'))) {
    await db.schema.alterTable('messages').addColumn('flag_reasons', 'jsonb').execute();
  }
  if (!(await hasColumn(db, 'messages', 'flag_summary'))) {
    await db.schema.alterTable('messages').addColumn('flag_summary', 'text').execute();
  }
  if (!(await hasColumn(db, 'messages', 'flag_reviewed_at'))) {
    await db.schema.alterTable('messages').addColumn('flag_reviewed_at', 'timestamptz').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('messages').dropColumn('flag_reviewed_at').execute();
  await db.schema.alterTable('messages').dropColumn('flag_summary').execute();
  await db.schema.alterTable('messages').dropColumn('flag_reasons').execute();
  await db.schema.alterTable('messages').dropColumn('flag_risk').execute();
}
