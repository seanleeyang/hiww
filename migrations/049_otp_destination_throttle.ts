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
 * `otp_codes` previously had no record of WHERE a code was sent, only which
 * user/channel it belonged to — so nothing could stop many different
 * accounts (free to create, e.g. via disposable emails) from all targeting
 * the same phone number or email, each triggering a fresh send with no
 * per-destination limit. `issueOtp` (src/services/otp/service.ts) now
 * throttles per `(channel, destination)` across ALL users, which needs the
 * destination actually stored to check against.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'otp_codes', 'destination'))) {
    await db.schema.alterTable('otp_codes').addColumn('destination', 'text').execute();
  }

  await db.schema
    .createIndex('otp_codes_channel_destination_created_idx')
    .ifNotExists()
    .on('otp_codes')
    .columns(['channel', 'destination', 'created_at'])
    .execute();
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropIndex('otp_codes_channel_destination_created_idx').ifExists().execute();
  await db.schema.alterTable('otp_codes').dropColumn('destination').execute();
}
