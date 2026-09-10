import 'dotenv/config';
import { Pool } from 'pg';
import { Kysely, PostgresDialect } from 'kysely';
import { migrations } from '../migrations/list';

/**
 * Boot the API against a throwaway `<db>_e2e` database for the Flutter
 * end-to-end suite (`mobile/integration_test/app_flow_test.dart`).
 *
 *   npm run dev:e2e          # in one terminal
 *   cd mobile && flutter test -d flutter-tester integration_test/app_flow_test.dart
 *
 * The database is dropped, recreated and migrated on every start, and a
 * pilot-admin account is seeded so the suite's admin-only steps (confirm
 * payment, resolve dispute, approve KYC) work without a separate script.
 * This is the same treatment `npm test` already gives the Jest suite via
 * `tests/global-setup.ts` — the dev / demo database is never touched.
 */

const BASE =
  process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/hiww';

function withDbName(name: string): string {
  const u = new URL(BASE);
  u.pathname = `/${name}`;
  return u.toString();
}

const parsed = new URL(BASE);
if (parsed.hostname !== 'localhost' && parsed.hostname !== '127.0.0.1') {
  throw new Error(`Refusing to run the e2e reset against a non-local host: ${parsed.hostname}`);
}

const baseName = parsed.pathname.replace(/^\//, '') || 'hiww';
const E2E_DB_NAME = baseName.endsWith('_e2e') ? baseName : `${baseName}_e2e`;
const E2E_DATABASE_URL = withDbName(E2E_DB_NAME);
const ADMIN_DATABASE_URL = withDbName('postgres');

// Kept in sync with the constants in app_flow_test.dart's `_adminToken()`.
const ADMIN_EMAIL = 'it-admin@example.com';
const ADMIN_PASSWORD = 'AdminPass123';

async function resetAndMigrate(): Promise<void> {
  const admin = new Pool({ connectionString: ADMIN_DATABASE_URL });
  try {
    await admin.query(
      `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = $1 AND pid <> pg_backend_pid()`,
      [E2E_DB_NAME],
    );
    await admin.query(`DROP DATABASE IF EXISTS ${E2E_DB_NAME}`);
    await admin.query(`CREATE DATABASE ${E2E_DB_NAME}`);
  } finally {
    await admin.end();
  }

  const db = new Kysely<unknown>({
    dialect: new PostgresDialect({ pool: new Pool({ connectionString: E2E_DATABASE_URL }) }),
  });
  try {
    for (const migration of migrations) await migration.up(db);
  } finally {
    await db.destroy();
  }
  console.log(`[e2e] fresh database ${E2E_DB_NAME}, ${migrations.length} migrations applied`);
}

async function seedAdmin(): Promise<void> {
  // Imported dynamically so `@/config/env` reads the e2e DATABASE_URL set below.
  const { createDatabase } = await import('@/db/connection');
  const { hashPassword } = await import('@/utils/auth');
  const { generateId } = await import('@/utils/helpers');

  const db = createDatabase();
  try {
    await db
      .insertInto('users')
      .values({
        id: generateId(),
        email: ADMIN_EMAIL,
        full_name: 'Pilot Admin',
        user_type: 'both',
        role: 'admin',
        kyc_status: 'approved',
        password_hash: hashPassword(ADMIN_PASSWORD),
        email_verified_at: new Date(),
        phone_verified_at: new Date(),
        created_at: new Date(),
        updated_at: new Date(),
      })
      .execute();
  } finally {
    await db.destroy();
  }
  console.log(`[e2e] seeded admin ${ADMIN_EMAIL}`);
}

async function main(): Promise<void> {
  await resetAndMigrate();
  process.env.DATABASE_URL = E2E_DATABASE_URL;
  process.env.NODE_ENV = process.env.NODE_ENV || 'development';
  // The whole suite hammers one IP — every seed call, every background poll
  // and every uploaded-image fetch. The rate limits are real product
  // behaviour (covered by tests/integration/rate-limit-flow.test.ts), just
  // not what this rig is testing, so lift them well clear for the run.
  process.env.RATE_LIMIT_MAX ||= '100000';
  process.env.AUTH_RATE_LIMIT_MAX ||= '100000';
  process.env.MONEY_RATE_LIMIT_MAX ||= '100000';
  process.env.UPLOAD_RATE_LIMIT_MAX ||= '100000';
  await seedAdmin();
  await import('../src/main');
}

main().catch((err) => {
  console.error('Failed to start the e2e server:', err);
  process.exit(1);
});
