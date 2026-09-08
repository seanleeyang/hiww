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
async function hasConstraint(db: Kysely<any>, name: string): Promise<boolean> {
  const result = await sql<{ exists: boolean }>`
    SELECT EXISTS (
      SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = ${name}
    ) AS exists
  `.execute(db);
  return result.rows[0]?.exists ?? false;
}

/**
 * Lets a user sign in with Google/Apple/Facebook/LINE instead of an email +
 * password. `password_hash` was already nullable (migration 002), so a
 * social-only account just leaves it null. `provider_user_id` is that
 * provider's own stable subject id, not the email — an email can change or
 * be reused across providers, a subject id can't. The unique constraint
 * covers both columns together: Postgres treats each NULL as distinct from
 * every other NULL, so the many existing email/password rows (both columns
 * null) never conflict with each other or with a social row.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'users', 'auth_provider'))) {
    await db.schema.alterTable('users').addColumn('auth_provider', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'users', 'provider_user_id'))) {
    await db.schema.alterTable('users').addColumn('provider_user_id', 'varchar').execute();
  }
  if (!(await hasConstraint(db, 'users_auth_provider_id_unique'))) {
    await db.schema
      .alterTable('users')
      .addUniqueConstraint('users_auth_provider_id_unique', ['auth_provider', 'provider_user_id'])
      .execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('users').dropConstraint('users_auth_provider_id_unique').execute();
  await db.schema.alterTable('users').dropColumn('provider_user_id').execute();
  await db.schema.alterTable('users').dropColumn('auth_provider').execute();
}
