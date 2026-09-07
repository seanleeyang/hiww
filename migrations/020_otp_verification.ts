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
 * Email + phone verification at registration. `otp_codes` holds short-lived
 * one-time codes for both channels (see `src/services/otp/`). Every EXISTING
 * user is grandfathered as already-verified (backfilled below) — the new
 * requirement only applies to accounts registered from here on; the register
 * route explicitly leaves both columns null for new signups.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'users', 'email_verified_at'))) {
    await db.schema.alterTable('users').addColumn('email_verified_at', 'timestamp').execute();
  }
  if (!(await hasColumn(db, 'users', 'phone_verified_at'))) {
    await db.schema.alterTable('users').addColumn('phone_verified_at', 'timestamp').execute();
  }

  await sql`
    UPDATE users
    SET email_verified_at = COALESCE(email_verified_at, created_at),
        phone_verified_at = COALESCE(phone_verified_at, created_at)
  `.execute(db);

  if (!(await hasTable(db, 'otp_codes'))) {
    await db.schema
      .createTable('otp_codes')
      .addColumn('id', 'uuid', (col) => col.primaryKey())
      .addColumn('user_id', 'uuid', (col) => col.notNull().references('users.id').onDelete('cascade'))
      .addColumn('channel', 'text', (col) => col.notNull())
      .addColumn('code', 'text', (col) => col.notNull())
      .addColumn('expires_at', 'timestamp', (col) => col.notNull())
      .addColumn('consumed_at', 'timestamp')
      .addColumn('created_at', 'timestamp', (col) => col.notNull().defaultTo(sql`now()`))
      .execute();

    await db.schema
      .createIndex('otp_codes_user_channel_idx')
      .on('otp_codes')
      .columns(['user_id', 'channel'])
      .execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('otp_codes').ifExists().execute();
  await db.schema.alterTable('users').dropColumn('email_verified_at').execute();
  await db.schema.alterTable('users').dropColumn('phone_verified_at').execute();
}
