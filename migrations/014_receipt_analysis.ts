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
 * Output of the AI receipt check (see `src/services/ai/`). `receipt_risk` is a
 * denormalised copy of `receipt_analysis->>'risk'` so the operator review queue
 * can filter on it cheaply; `receipt_reviewed_at` is set when an operator has
 * looked at a flagged receipt and cleared it from the queue.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'orders', 'receipt_analysis'))) {
    await db.schema.alterTable('orders').addColumn('receipt_analysis', 'jsonb').execute();
  }
  if (!(await hasColumn(db, 'orders', 'receipt_risk'))) {
    await db.schema.alterTable('orders').addColumn('receipt_risk', 'text').execute();
  }
  if (!(await hasColumn(db, 'orders', 'receipt_reviewed_at'))) {
    await db.schema.alterTable('orders').addColumn('receipt_reviewed_at', 'timestamptz').execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('orders').dropColumn('receipt_reviewed_at').execute();
  await db.schema.alterTable('orders').dropColumn('receipt_risk').execute();
  await db.schema.alterTable('orders').dropColumn('receipt_analysis').execute();
}
