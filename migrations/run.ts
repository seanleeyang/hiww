import 'dotenv/config';
import { sql } from 'kysely';
import { createDatabase } from '@/db/connection';
import { migrations } from './list';

// Postgres "already exists" error classes — tolerated so a migration that was
// applied before this tracking table existed is recorded, not re-run.
const ALREADY_EXISTS = new Set(['42P07', '42710', '42701', '42P06', '42723', '42P16']);

/**
 * Safe to run on every deploy: a `_migrations` table records what has been
 * applied, and each migration runs at most once.
 */
async function runMigrations(): Promise<void> {
  const db = createDatabase();
  console.log('🚀 Running migrations…');

  try {
    await sql`
      CREATE TABLE IF NOT EXISTS _migrations (
        name text PRIMARY KEY,
        applied_at timestamptz NOT NULL DEFAULT now()
      )
    `.execute(db);

    const rows = await sql<{ name: string }>`SELECT name FROM _migrations`.execute(db);
    const applied = new Set(rows.rows.map((r) => r.name));

    for (const migration of migrations) {
      if (applied.has(migration.name)) {
        console.log(`↷  ${migration.name} (already applied)`);
        continue;
      }
      try {
        await migration.up(db);
        console.log(`✅ ${migration.name}`);
      } catch (err) {
        const code = (err as { code?: string } | undefined)?.code;
        if (code && ALREADY_EXISTS.has(code)) {
          console.log(`↷  ${migration.name} (objects already present — recording)`);
        } else {
          throw err;
        }
      }
      await sql`INSERT INTO _migrations (name) VALUES (${migration.name}) ON CONFLICT DO NOTHING`.execute(db);
    }

    console.log('✅ All migrations up to date');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    await db.destroy();
    process.exit(1);
  }
  await db.destroy();
}

runMigrations();
