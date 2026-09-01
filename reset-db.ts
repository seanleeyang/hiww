import { Pool } from 'pg';

async function resetDatabase(): Promise<void> {
  const pool = new Pool({
    user: 'postgres',
    password: 'Davidbarr@1',
    host: 'localhost',
    port: 5432,
    database: 'postgres', // Connect to default postgres db first
  });

  try {
    // Drop existing database if it exists
    await pool.query('DROP DATABASE IF EXISTS hiww;');
    console.log('✅ Dropped old database');

    // Create fresh database
    await pool.query('CREATE DATABASE hiww;');
    console.log('✅ Created fresh database "hiww"');
  } catch (error: any) {
    console.error('❌ Error:', error.message);
    throw error;
  } finally {
    await pool.end();
  }
}

resetDatabase().catch((err) => {
  console.error('Failed:', err);
  process.exit(1);
});
