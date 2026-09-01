import { Pool } from 'pg';
import { Kysely, PostgresDialect } from 'kysely';
import type { Database } from '@/types/database';
import { config } from '@/config/env';

export function createDatabase(): Kysely<Database> {
  const dialect = new PostgresDialect({
    pool: new Pool({
      connectionString: config.databaseUrl,
      max: parseInt(process.env.DB_POOL_SIZE || '20'),
      idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT || '30000'),
    }),
  });

  return new Kysely<Database>({
    dialect,
  });
}

export type DB = Kysely<Database>;
