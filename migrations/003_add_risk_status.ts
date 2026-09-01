import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  const result = await sql<{ exists: boolean }>`
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'users'
        AND column_name = 'risk_status'
    ) AS exists
  `.execute(db);

  if (!result.rows[0]?.exists) {
    await db.schema
      .alterTable('users')
      .addColumn('risk_status', 'varchar', (col) => col.notNull().defaultTo('clear'))
      .execute();
  }
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable('users').dropColumn('risk_status').execute();
}
