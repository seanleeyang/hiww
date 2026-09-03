// Jest globalSetup: drop + recreate the test database and run every migration,
// once per `npm test`. Keeps the suite hermetic and off the dev / demo db.
import 'dotenv/config';
import { Pool } from 'pg';
import { Kysely, PostgresDialect } from 'kysely';
import { TEST_DATABASE_URL, TEST_DB_NAME, ADMIN_DATABASE_URL } from './helpers/test-db-url';

import * as m001 from '../migrations/001_init';
import * as m002 from '../migrations/002_add_auth_fields';
import * as m003 from '../migrations/003_add_risk_status';
import * as m004 from '../migrations/004_add_user_role';
import * as m005 from '../migrations/005_add_order_payment_claim';
import * as m006 from '../migrations/006_add_offer_trip';
import * as m007 from '../migrations/007_profiles_and_discovery';
import * as m008 from '../migrations/008_reviews';
import * as m009 from '../migrations/009_messages';
import * as m010 from '../migrations/010_audit_log';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const MIGRATIONS: Array<(db: any) => Promise<void>> = [
  m001.up, m002.up, m003.up, m004.up, m005.up,
  m006.up, m007.up, m008.up, m009.up, m010.up,
];

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
    for (const up of MIGRATIONS) await up(db);
  } finally {
    await db.destroy();
  }
}
