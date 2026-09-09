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
 * Order chat closes once the order reaches `delivered` (the shopper
 * confirmed receipt and released payment) — see `messages/routes.ts`.
 * These two nullable per-side timestamps let either party "delete" a
 * closed chat from their own inbox/view without touching the other
 * party's copy or the underlying message rows, which stay intact for
 * dispute/support reference.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  for (const column of ['chat_deleted_by_shopper_at', 'chat_deleted_by_traveler_at']) {
    if (!(await hasColumn(db, 'orders', column))) {
      await db.schema.alterTable('orders').addColumn(column, 'timestamp').execute();
    }
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('orders').dropColumn('chat_deleted_by_traveler_at').execute();
  await db.schema.alterTable('orders').dropColumn('chat_deleted_by_shopper_at').execute();
}
