import { Kysely, sql } from 'kysely';

/**
 * One row per device a user has registered for push notifications (see
 * `src/services/push/`, `src/modules/devices/routes.ts`). A user can have
 * several — phone, tablet, a browser tab on web — each pushed to
 * independently. `token` is unique across the whole table: re-registering
 * the same device (e.g. after an FCM token refresh) re-points it at
 * whichever user is currently signed in there rather than creating a
 * duplicate row.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .createTable('device_tokens')
    .ifNotExists()
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    .addColumn('user_id', 'uuid', (col) =>
      col.notNull().references('users.id').onDelete('cascade')
    )
    .addColumn('token', 'text', (col) => col.notNull().unique())
    .addColumn('platform', 'varchar', (col) => col.notNull())
    .addColumn('created_at', 'timestamp', (col) => col.notNull().defaultTo(sql`now()`))
    .addColumn('updated_at', 'timestamp', (col) => col.notNull().defaultTo(sql`now()`))
    .execute();

  await db.schema
    .createIndex('device_tokens_user_id_idx')
    .ifNotExists()
    .on('device_tokens')
    .column('user_id')
    .execute();
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropIndex('device_tokens_user_id_idx').ifExists().execute();
  await db.schema.dropTable('device_tokens').ifExists().execute();
}
