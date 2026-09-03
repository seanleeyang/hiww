import 'dotenv/config';
import { createDatabase } from '@/db/connection';
import { migrations } from './list';

async function runMigrations(): Promise<void> {
  const db = createDatabase();

  console.log('🚀 Running migrations...');

  try {
    for (const migration of migrations) {
      await migration.up(db);
      console.log(`✅ Migration ${migration.name} completed`);
    }
    await db.destroy();
    console.log('✅ All migrations completed successfully');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    await db.destroy();
    process.exit(1);
  }
}

runMigrations();
