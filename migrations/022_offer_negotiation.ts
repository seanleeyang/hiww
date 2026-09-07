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
 * Turns a one-shot offer into a short negotiation: either side can counter
 * instead of only accepting, capped at 2 counters total so a deal resolves
 * fast rather than dragging on (see `src/modules/offers/routes.ts`). Each
 * price on the table has its own response deadline, enforced lazily like
 * the payment timeout — see `src/services/offer-expiry.ts`.
 *
 * `round` counts counters made so far (0 = still the traveler's opening
 * price). `last_actor` says who proposed the current `quoted_price` — the
 * other side is the one who can accept/reject/counter next. `price_history`
 * keeps every price proposed, for the negotiation thread UI.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'offers', 'round'))) {
    await db.schema
      .alterTable('offers')
      .addColumn('round', 'integer', (col) => col.notNull().defaultTo(0))
      .execute();
  }
  if (!(await hasColumn(db, 'offers', 'last_actor'))) {
    await db.schema.alterTable('offers').addColumn('last_actor', 'text').execute();
  }
  if (!(await hasColumn(db, 'offers', 'respond_by'))) {
    await db.schema.alterTable('offers').addColumn('respond_by', 'timestamp').execute();
  }
  if (!(await hasColumn(db, 'offers', 'price_history'))) {
    await db.schema
      .alterTable('offers')
      .addColumn('price_history', 'jsonb', (col) => col.notNull().defaultTo(sql`'[]'::jsonb`))
      .execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('offers').dropColumn('round').execute();
  await db.schema.alterTable('offers').dropColumn('last_actor').execute();
  await db.schema.alterTable('offers').dropColumn('respond_by').execute();
  await db.schema.alterTable('offers').dropColumn('price_history').execute();
}
