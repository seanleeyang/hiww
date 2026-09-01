import { Kysely, sql } from 'kysely';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  const result = await sql<{ exists: boolean }>`
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'offers' AND column_name = 'trip_id'
    ) AS exists
  `.execute(db);

  if (!result.rows[0]?.exists) {
    await db.schema
      .alterTable('offers')
      .addColumn('trip_id', 'uuid', (col) => col.references('trips.id').onDelete('set null'))
      .execute();
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('offers').dropColumn('trip_id').execute();
}
