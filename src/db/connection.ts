import { Pool, type PoolConfig, types as pgTypes } from 'pg';
import { Kysely, PostgresDialect } from 'kysely';
import type { Database } from '@/types/database';
import { config } from '@/config/env';

// `pg`'s default DATE (oid 1082) parser builds a JS Date at local midnight.
// Serialising that via `.toISOString()` on a server not running in UTC
// shifts the calendar date by a day — a real risk for `users.date_of_birth`
// (age is checked against it). Keep it as the plain 'YYYY-MM-DD' string
// Postgres already returns; nothing in this codebase wants a Date object
// for a date-only column.
pgTypes.setTypeParser(1082, (value) => value);

/**
 * Managed Postgres (Neon, Render, Supabase, RDS…) requires TLS. `pg` does not
 * enable it from `sslmode=` in the URL on its own, so switch it on whenever the
 * URL asks for it, points at a known managed host, or we are in production.
 */
function sslFor(url: string): PoolConfig['ssl'] {
  const wantsSsl =
    /[?&]sslmode=(require|verify-ca|verify-full)/.test(url) ||
    /\.(neon\.tech|render\.com|supabase\.co|rds\.amazonaws\.com)/.test(url) ||
    (config.nodeEnv === 'production' && !/@(localhost|127\.0\.0\.1)[:/]/.test(url));

  // Managed providers terminate TLS with their own CA; `require` (encrypt, don't
  // pin the CA) is the pragmatic setting and what their dashboards hand you.
  return wantsSsl ? { rejectUnauthorized: false } : undefined;
}

export function createDatabase(): Kysely<Database> {
  const dialect = new PostgresDialect({
    pool: new Pool({
      connectionString: config.databaseUrl,
      ssl: sslFor(config.databaseUrl),
      max: parseInt(process.env.DB_POOL_SIZE || '20'),
      idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT || '30000'),
    }),
  });

  return new Kysely<Database>({
    dialect,
  });
}

export type DB = Kysely<Database>;
