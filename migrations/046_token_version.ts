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
 * A login token used to be valid for its full 7-day life no matter what —
 * there was no way to cut one off early if it leaked (stolen phone,
 * compromised account). Every issued token now carries the account's
 * `token_version` at the moment it was signed; the auth guard rejects a
 * token whose version doesn't match the account's *current* value (see
 * src/middleware/auth-guard.ts). Bumping this column invalidates every
 * token issued before that moment, in one write, without tracking
 * individual sessions — done automatically on password change/reset (see
 * auth/routes.ts) and by the admin "flag" action for a restricted account
 * (see admin/actions.ts).
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'users', 'token_version'))) {
    await db.schema
      .alterTable('users')
      .addColumn('token_version', 'integer', (col) => col.notNull().defaultTo(0))
      .execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('users').dropColumn('token_version').execute();
}
