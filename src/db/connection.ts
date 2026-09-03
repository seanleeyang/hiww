import { Pool, type PoolConfig } from 'pg';
import { Kysely, PostgresDialect } from 'kysely';
import type { Database } from '@/types/database';
import { config } from '@/config/env';

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
