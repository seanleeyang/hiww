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
 * A shopper can request an item directly off one traveler's trip (the
 * "Request from this trip" button) instead of posting a public want any
 * traveler can bid on. `target_trip_id` marks that — such a want is
 * excluded from the public browse feed (see `GET /api/requests`) and its
 * creation auto-opens a negotiation with that trip's traveler instead of
 * waiting for someone to notice it (see `src/modules/requests/routes.ts`).
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'requests', 'target_trip_id'))) {
    await db.schema
      .alterTable('requests')
      .addColumn('target_trip_id', 'uuid', (col) => col.references('trips.id').onDelete('set null'))
      .execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('requests').dropColumn('target_trip_id').execute();
}
