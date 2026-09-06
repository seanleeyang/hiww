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
 * A message the async AI moderation pass called high-risk is retroactively
 * hidden from both participants (an operator can still see it in the review
 * queue) rather than deleted outright — see `src/services/chat-moderation.ts`
 * `presentMessageBody`. The synchronous regex pass never needs this; it
 * redacts the offending text in place before the message is even stored.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'messages', 'hidden_at'))) {
    await db.schema.alterTable('messages').addColumn('hidden_at', 'timestamptz').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('messages').dropColumn('hidden_at').execute();
}
