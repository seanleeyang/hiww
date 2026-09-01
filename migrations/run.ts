import 'dotenv/config';
import { createDatabase } from '@/db/connection';
import * as migration001 from './001_init';
import * as migration002 from './002_add_auth_fields';
import * as migration003 from './003_add_risk_status';
import * as migration004 from './004_add_user_role';
import * as migration005 from './005_add_order_payment_claim';
import * as migration006 from './006_add_offer_trip';

async function runMigrations(): Promise<void> {
  const db = createDatabase();

  console.log('🚀 Running migrations...');

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const migrations: Array<{ name: string; up: (db: any) => Promise<void> }> = [
    { name: '001_init', up: migration001.up },
    { name: '002_add_auth_fields', up: migration002.up },
    { name: '003_add_risk_status', up: migration003.up },
    { name: '004_add_user_role', up: migration004.up },
    { name: '005_add_order_payment_claim', up: migration005.up },
    { name: '006_add_offer_trip', up: migration006.up },
  ];

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
