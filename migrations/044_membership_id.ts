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
 * A short, human-referenceable membership number (formatted client/server-side
 * as `H` + an 8-digit zero-padded sequence, e.g. `H00000123`) so admins and
 * support can refer to an account without reading out a UUID or relying on
 * name/email matches. `member_seq` is the raw integer; a Postgres sequence
 * backs the column default so every new signup gets the next number for
 * free, while existing users are backfilled in signup order.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'users', 'member_seq'))) {
    await db.schema.alterTable('users').addColumn('member_seq', 'integer').execute();

    await sql`
      UPDATE users SET member_seq = ranked.rn
      FROM (SELECT id, ROW_NUMBER() OVER (ORDER BY created_at, id) AS rn FROM users) AS ranked
      WHERE users.id = ranked.id
    `.execute(db);

    await sql`CREATE SEQUENCE IF NOT EXISTS users_member_seq_seq`.execute(db);
    // is_called=false when the table is empty so the *next* value is still 1
    // (setval's value arg must be >= 1, and passing is_called=true would
    // make the first real signup skip straight to 2).
    await sql`
      SELECT setval(
        'users_member_seq_seq',
        COALESCE((SELECT MAX(member_seq) FROM users), 1),
        (SELECT MAX(member_seq) FROM users) IS NOT NULL
      )
    `.execute(db);
    await sql`ALTER TABLE users ALTER COLUMN member_seq SET DEFAULT nextval('users_member_seq_seq')`.execute(db);
    await sql`ALTER TABLE users ALTER COLUMN member_seq SET NOT NULL`.execute(db);
    await db.schema
      .alterTable('users')
      .addUniqueConstraint('users_member_seq_key', ['member_seq'])
      .execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('users').dropColumn('member_seq').execute();
  await sql`DROP SEQUENCE IF EXISTS users_member_seq_seq`.execute(db);
}
