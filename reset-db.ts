import 'dotenv/config';
import { Pool } from 'pg';

/**
 * Drop and recreate the `hiww` database. Destructive — local development only.
 *
 * Connection details come from the environment. Set ADMIN_DATABASE_URL to a
 * connection string that points at the `postgres` maintenance database (same
 * credentials as DATABASE_URL, different database name), or rely on the parsed
 * DATABASE_URL below.
 */
function resolveAdminConnection(): { connectionString: string; targetDb: string } {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is not set. Copy .env.example to .env and fill it in.');
  }

  const parsed = new URL(databaseUrl);
  const targetDb = parsed.pathname.replace(/^\//, '') || 'hiww';

  if (!/^[a-zA-Z0-9_]+$/.test(targetDb)) {
    throw new Error(`Unexpected database name in DATABASE_URL: ${targetDb}`);
  }

  if (parsed.hostname !== 'localhost' && parsed.hostname !== '127.0.0.1') {
    throw new Error(`Refusing to reset a non-local database host: ${parsed.hostname}`);
  }

  const adminUrl = process.env.ADMIN_DATABASE_URL
    ? new URL(process.env.ADMIN_DATABASE_URL)
    : new URL(databaseUrl);
  if (!process.env.ADMIN_DATABASE_URL) {
    adminUrl.pathname = '/postgres';
  }

  return { connectionString: adminUrl.toString(), targetDb };
}

async function resetDatabase(): Promise<void> {
  const { connectionString, targetDb } = resolveAdminConnection();
  const pool = new Pool({ connectionString });

  try {
    await pool.query(`DROP DATABASE IF EXISTS "${targetDb}";`);
    console.log(`✅ Dropped old database "${targetDb}"`);
    await pool.query(`CREATE DATABASE "${targetDb}";`);
    console.log(`✅ Created fresh database "${targetDb}"`);
  } finally {
    await pool.end();
  }
}

resetDatabase().catch((err) => {
  console.error('Failed:', err);
  process.exit(1);
});
