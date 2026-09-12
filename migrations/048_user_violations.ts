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

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function hasTable(db: Kysely<any>, table: string): Promise<boolean> {
  const result = await sql<{ exists: boolean }>`
    SELECT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = ${table}
    ) AS exists
  `.execute(db);
  return result.rows[0]?.exists ?? false;
}

/**
 * A 3-strikes system on top of the existing `users.risk_status` — see
 * src/services/violations.ts. Each row here is one admin-logged violation;
 * the count of them for a user drives auto-escalation:
 *   1st -> risk_status 'flagged' (a warning, no lockout)
 *   2nd -> risk_status 'restricted', suspended_until = now + 7 days
 *   3rd -> risk_status 'restricted', suspended_until stays null (permanent)
 * `suspended_until` is what actually gates login (see auth-guard.ts and
 * POST /api/auth/login) — null while restricted means "no end date", i.e.
 * a permanent ban; a manual admin "flag as restricted" (no violation
 * attached) also defaults to null, same as before this existed.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'users', 'suspended_until'))) {
    await db.schema.alterTable('users').addColumn('suspended_until', 'timestamptz').execute();
  }

  if (!(await hasTable(db, 'user_violations'))) {
    await db.schema
      .createTable('user_violations')
      .addColumn('id', 'uuid', (col) => col.primaryKey())
      .addColumn('user_id', 'uuid', (col) => col.notNull().references('users.id').onDelete('cascade'))
      .addColumn('reason', 'text', (col) => col.notNull())
      .addColumn('issued_by', 'uuid', (col) => col.references('users.id').onDelete('set null'))
      .addColumn('created_at', 'timestamptz', (col) => col.notNull().defaultTo(sql`now()`))
      .execute();

    await db.schema
      .createIndex('user_violations_user_created_idx')
      .on('user_violations')
      .columns(['user_id', 'created_at'])
      .execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropIndex('user_violations_user_created_idx').ifExists().execute();
  await db.schema.dropTable('user_violations').ifExists().execute();
  await db.schema.alterTable('users').dropColumn('suspended_until').execute();
}
