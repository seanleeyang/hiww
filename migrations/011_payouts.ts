import { Kysely, sql } from 'kysely';

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
 * One row per traveller payout. During the manual-money pilot the operator moves
 * the money out of band (Wise / bank / PromptPay) once an order is `delivered`,
 * then records it here so reconciliation knows the order is settled. `amount` is
 * what actually left the operator's account — normally the order's `total_price`
 * (the goods price; the platform keeps `fees`).
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (await hasTable(db, 'payouts')) return;

  await db.schema
    .createTable('payouts')
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    .addColumn('order_id', 'uuid', (col) =>
      col.notNull().unique().references('orders.id').onDelete('cascade')
    )
    .addColumn('recorded_by', 'uuid', (col) => col.references('users.id').onDelete('set null'))
    .addColumn('amount', 'text', (col) => col.notNull())
    .addColumn('method', 'text', (col) => col.notNull())
    .addColumn('reference', 'text', (col) => col.notNull())
    .addColumn('note', 'text')
    .addColumn('created_at', 'timestamptz', (col) => col.notNull().defaultTo(sql`now()`))
    .execute();
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('payouts').ifExists().execute();
}
