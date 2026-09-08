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
 * Structured data behind each notification, so `GET /api/notifications` can
 * re-render `subject`/`body` in the reader's locale (see `src/i18n/notifications.ts`)
 * instead of returning whatever text got baked in at write time. Rows written
 * before this migration have no `params` and keep showing their stored
 * (English) `subject`/`body` — see `recordNotification()`.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'notifications', 'params'))) {
    await db.schema.alterTable('notifications').addColumn('params', 'jsonb').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('notifications').dropColumn('params').execute();
}
