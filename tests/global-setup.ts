// Jest globalSetup: drop + recreate the test database and run every migration,
// once per `npm test`. Keeps the suite hermetic and off the dev / demo db.
import 'dotenv/config';
import { Pool } from 'pg';
import { Kysely, PostgresDialect } from 'kysely';
import { TEST_DATABASE_URL, TEST_DB_NAME, ADMIN_DATABASE_URL } from './helpers/test-db-url';
import { migrations } from '../migrations/list';

export default async function globalSetup(): Promise<void> {
  const admin = new Pool({ connectionString: ADMIN_DATABASE_URL });
  try {
    await admin.query(
      `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = $1 AND pid <> pg_backend_pid()`,
      [TEST_DB_NAME],
    );
    await admin.query(`DROP DATABASE IF EXISTS ${TEST_DB_NAME}`);
    await admin.query(`CREATE DATABASE ${TEST_DB_NAME}`);
  } finally {
    await admin.end();
  }

  const db = new Kysely<unknown>({
    dialect: new PostgresDialect({ pool: new Pool({ connectionString: TEST_DATABASE_URL }) }),
  });
  try {
    for (const migration of migrations) await migration.up(db);
  } finally {
    await db.destroy();
  }
}
