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
 * A cancelled/completed trip or want has no "delete" option today (delete
 * only works while `published`/`open`, to avoid orphaning any offer that
 * referenced it) — it just sits in My Trips/My Wants forever. `archived_at`
 * lets the owner clear it from THEIR OWN list without touching the row's
 * history: excluded from `GET /api/trips/mine` / `GET /api/requests/mine`
 * once set, but the row (and any offer/order/audit tied to it) is untouched.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'trips', 'archived_at'))) {
    await db.schema.alterTable('trips').addColumn('archived_at', 'timestamp').execute();
  }
  if (!(await hasColumn(db, 'requests', 'archived_at'))) {
    await db.schema.alterTable('requests').addColumn('archived_at', 'timestamp').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('trips').dropColumn('archived_at').execute();
  await db.schema.alterTable('requests').dropColumn('archived_at').execute();
}
