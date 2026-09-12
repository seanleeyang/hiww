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
 * Bank Account box on the mobile Account page — lets a user record which
 * bank to pay their payouts to, so an admin doesn't have to ask each order.
 * Purely informational for now: `POST /api/payments/payout` still takes its
 * own free-text `reference` and isn't wired to read these columns.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'users', 'bank_name'))) {
    await db.schema.alterTable('users').addColumn('bank_name', 'varchar').execute();
  }
  if (!(await hasColumn(db, 'users', 'bank_account_number'))) {
    await db.schema.alterTable('users').addColumn('bank_account_number', 'varchar').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('users').dropColumn('bank_account_number').execute();
  await db.schema.alterTable('users').dropColumn('bank_name').execute();
}
