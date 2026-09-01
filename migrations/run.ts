import 'dotenv/config';
import { createDatabase } from '@/db/connection';
import * as migration001 from './001_init';
import * as migration002 from './002_add_auth_fields';
import * as migration003 from './003_add_risk_status';

async function runMigrations(): Promise<void> {
  const db = createDatabase();

  console.log('🚀 Running migrations...');

  try {
    await migration001.up(db);
    console.log('✅ Migration 001_init completed');
    await migration002.up(db);
    console.log('✅ Migration 002_add_auth_fields completed');
    await migration003.up(db);
    console.log('✅ Migration 003_add_risk_status completed');
    await db.destroy();
    console.log('✅ All migrations completed successfully');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    await db.destroy();
    process.exit(1);
  }
}

runMigrations();
