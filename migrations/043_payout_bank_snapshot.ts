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
 * Snapshots the traveller's `users.bank_name`/`bank_account_number` (added in
 * migration 042) onto the `payouts` row at the moment a payout is recorded.
 * The admin never types a destination account — `POST /api/payments/payout`
 * reads it server-side from the traveller's own profile — so this is purely
 * an audit trail of what was actually used, immune to the account being
 * edited afterwards and immune to an admin substituting their own account.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'payouts', 'bank_name'))) {
    await db.schema.alterTable('payouts').addColumn('bank_name', 'text').execute();
  }
  if (!(await hasColumn(db, 'payouts', 'bank_account_number'))) {
    await db.schema.alterTable('payouts').addColumn('bank_account_number', 'text').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('payouts').dropColumn('bank_account_number').execute();
  await db.schema.alterTable('payouts').dropColumn('bank_name').execute();
}
