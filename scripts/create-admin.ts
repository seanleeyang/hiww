import 'dotenv/config';
import { createInterface } from 'node:readline/promises';
import { stdin, stdout } from 'node:process';
import { createDatabase } from '@/db/connection';
import { hashPassword } from '@/utils/auth';
import { generateId } from '@/utils/helpers';

/**
 * Create (or promote) an admin account without touching the API.
 *
 *   npx tsx scripts/create-admin.ts               # interactive prompts
 *   npx tsx scripts/create-admin.ts a@b.com pass  # non-interactive
 *
 * If the email already exists it is promoted to admin (and the password is
 * updated to what you type). Otherwise a new admin user is created.
 */
async function main(): Promise<void> {
  let email = process.argv[2];
  let password = process.argv[3];

  if (!email || !password) {
    const rl = createInterface({ input: stdin, output: stdout });
    try {
      email = email || (await rl.question('Admin email: ')).trim();
      password = password || (await rl.question('Admin password (min 8 chars): ')).trim();
    } finally {
      rl.close();
    }
  }

  if (!email || !password || password.length < 8) {
    console.error('Need an email and a password of at least 8 characters.');
    process.exit(1);
  }

  const db = createDatabase();
  try {
    const existing = await db
      .selectFrom('users')
      .select(['id', 'role'])
      .where('email', '=', email)
      .executeTakeFirst();

    if (existing) {
      await db
        .updateTable('users')
        .set({ role: 'admin', kyc_status: 'approved', password_hash: hashPassword(password), updated_at: new Date() })
        .where('id', '=', existing.id)
        .execute();
      console.log(`\n✅ ${email} promoted to admin (password updated).`);
    } else {
      await db
        .insertInto('users')
        .values({
          id: generateId(),
          email,
          full_name: 'Pilot Admin',
          user_type: 'both',
          role: 'admin',
          kyc_status: 'approved',
          password_hash: hashPassword(password),
          // Bypasses the register route's OTP flow — grandfather this
          // account in as already-verified, same as every pre-existing user.
          email_verified_at: new Date(),
          phone_verified_at: new Date(),
          created_at: new Date(),
          updated_at: new Date(),
        })
        .execute();
      console.log(`\n✅ Admin account created: ${email}`);
    }
    console.log('   Log in at http://localhost:3000/admin');
  } finally {
    await db.destroy();
  }
}

main().catch((err) => {
  console.error('Failed:', err);
  process.exit(1);
});
