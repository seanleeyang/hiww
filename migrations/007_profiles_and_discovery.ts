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
 * Additive columns that let the app render a consumer-grade marketplace:
 * profile + reputation on users, richer trips/requests, and per-stage
 * timestamps on orders so the client can draw a dated progress tracker.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  const add = async (
    table: string,
    column: string,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    type: any,
    defaultValue?: number
  ): Promise<void> => {
    if (await hasColumn(db, table, column)) return;
    await db.schema
      .alterTable(table)
      .addColumn(column, type, (col) =>
        defaultValue === undefined ? col : col.notNull().defaultTo(defaultValue)
      )
      .execute();
  };

  await add('users', 'avatar_url', 'text');
  await add('users', 'home_city', 'text');
  await add('users', 'rating_sum', 'integer', 0);
  await add('users', 'rating_count', 'integer', 0);
  await add('users', 'delivered_count', 'integer', 0);

  await add('trips', 'title', 'text');
  await add('trips', 'departure_city', 'text');
  await add('trips', 'arrival_city', 'text');
  await add('trips', 'note', 'text');
  await add('trips', 'cover_image_url', 'text');

  await add('requests', 'title', 'text');
  await add('requests', 'source_city', 'text');
  await add('requests', 'need_by', 'timestamp');
  await add('requests', 'image_url', 'text');

  await add('orders', 'confirmed_at', 'timestamp');
  await add('orders', 'shipped_at', 'timestamp');
  await add('orders', 'delivered_at', 'timestamp');
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  const drop = (table: string, column: string) =>
    db.schema.alterTable(table).dropColumn(column).execute();

  await Promise.all([
    drop('users', 'avatar_url'),
    drop('users', 'home_city'),
    drop('users', 'rating_sum'),
    drop('users', 'rating_count'),
    drop('users', 'delivered_count'),
    drop('trips', 'title'),
    drop('trips', 'departure_city'),
    drop('trips', 'arrival_city'),
    drop('trips', 'note'),
    drop('trips', 'cover_image_url'),
    drop('requests', 'title'),
    drop('requests', 'source_city'),
    drop('requests', 'need_by'),
    drop('requests', 'image_url'),
    drop('orders', 'confirmed_at'),
    drop('orders', 'shipped_at'),
    drop('orders', 'delivered_at'),
  ]);
}
