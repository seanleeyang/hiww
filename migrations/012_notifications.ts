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
 * Turn the `notifications` table from a delivery-channel stub into an in-app
 * activity feed: every order state change drops a row here for each party, with
 * a `link` back to the order so a tap on the bell opens the right screen.
 *
 * `type` now holds the event kind (`payment_confirmed`, `shipped`, …); the app
 * no longer sends `email`/`sms`/`push` values. The column is a plain `varchar`
 * so no constraint change is needed — only the two new columns and an index.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  if (!(await hasColumn(db, 'notifications', 'order_id'))) {
    await db.schema
      .alterTable('notifications')
      .addColumn('order_id', 'uuid', (col) => col.references('orders.id').onDelete('cascade'))
      .execute();
  }

  if (!(await hasColumn(db, 'notifications', 'link'))) {
    await db.schema
      .alterTable('notifications')
      .addColumn('link', 'text')
      .execute();
  }

  await db.schema
    .createIndex('notifications_user_created_idx')
    .ifNotExists()
    .on('notifications')
    .columns(['user_id', 'created_at desc'])
    .execute();
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropIndex('notifications_user_created_idx').ifExists().execute();
  await db.schema.alterTable('notifications').dropColumn('link').execute();
  await db.schema.alterTable('notifications').dropColumn('order_id').execute();
}
