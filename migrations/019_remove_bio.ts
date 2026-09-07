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
 * `users.bio` (migration 018) is removed before it ever shipped to real
 * users: it was a public free-text field with no moderation, unlike order
 * chat's regex + AI leakage checks — an easy way to slip a phone number or
 * social handle past the platform. No replacement planned.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (await hasColumn(db, 'users', 'bio')) {
    await db.schema.alterTable('users').dropColumn('bio').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('users').addColumn('bio', 'text').execute();
}
