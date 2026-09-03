/**
 * The integration tests run against their own database so they never touch the
 * dev / demo one. It is `<your db>_test`, derived from `DATABASE_URL`.
 */
const BASE =
  process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/hiww';

function withDbName(name: string): string {
  const u = new URL(BASE);
  u.pathname = `/${name}`;
  return u.toString();
}

const baseName = new URL(BASE).pathname.replace(/^\//, '') || 'hiww';
export const TEST_DB_NAME = baseName.endsWith('_test') ? baseName : `${baseName}_test`;
export const TEST_DATABASE_URL = withDbName(TEST_DB_NAME);
/** An admin connection (to the `postgres` maintenance db) for CREATE/DROP. */
export const ADMIN_DATABASE_URL = withDbName('postgres');
