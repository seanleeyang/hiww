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
 * Append-only record of every state change that matters for a money pilot:
 * payment confirmations, the fund release, order lifecycle transitions, and
 * every admin action (KYC review, risk flag, dispute resolution).
 *
 * Rows are never updated or deleted by the app. `metadata` holds the before/after
 * and any money reference the operator typed in.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (await hasTable(db, 'audit_log')) return;

  await db.schema
    .createTable('audit_log')
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    // Nullable: an unauthenticated or system action still gets logged.
    .addColumn('actor_id', 'uuid', (col) => col.references('users.id').onDelete('set null'))
    .addColumn('actor_role', 'text')
    .addColumn('action', 'text', (col) => col.notNull())
    .addColumn('target_type', 'text', (col) => col.notNull())
    .addColumn('target_id', 'text', (col) => col.notNull())
    .addColumn('summary', 'text', (col) => col.notNull())
    .addColumn('metadata', 'jsonb', (col) => col.notNull().defaultTo(sql`'{}'::jsonb`))
    .addColumn('created_at', 'timestamptz', (col) => col.notNull().defaultTo(sql`now()`))
    .execute();

  await db.schema
    .createIndex('audit_log_target_idx')
    .on('audit_log')
    .columns(['target_type', 'target_id'])
    .execute();

  await db.schema
    .createIndex('audit_log_created_idx')
    .on('audit_log')
    .column('created_at desc')
    .execute();

  await db.schema
    .createIndex('audit_log_actor_idx')
    .on('audit_log')
    .column('actor_id')
    .execute();
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('audit_log').ifExists().execute();
}
