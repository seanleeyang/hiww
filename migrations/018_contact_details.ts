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
 * Contact + delivery details on users: phone, a structured address, and a
 * public bio. Phone/address are required before a user's first order (see
 * `src/utils/profile-guard.ts`) so both sides of a delivery can reach and
 * find each other; bio is optional and shown on the public profile.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const add = async (table: string, column: string, type: any): Promise<void> => {
    if (await hasColumn(db, table, column)) return;
    await db.schema.alterTable(table).addColumn(column, type).execute();
  };

  await add('users', 'phone', 'text');
  await add('users', 'bio', 'text');
  await add('users', 'address_street', 'text');
  await add('users', 'address_city', 'text');
  await add('users', 'address_postal_code', 'text');
  await add('users', 'address_country', 'text');
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function down(db: Kysely<any>): Promise<void> {
  const drop = (column: string) => db.schema.alterTable('users').dropColumn(column).execute();

  await Promise.all([
    drop('phone'),
    drop('bio'),
    drop('address_street'),
    drop('address_city'),
    drop('address_postal_code'),
    drop('address_country'),
  ]);
}
