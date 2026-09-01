import 'dotenv/config';
import { createDatabase } from '@/db/connection';

/**
 * Promote (or demote) a user to admin by email.
 *
 *   npx tsx scripts/make-admin.ts you@example.com
 *   npx tsx scripts/make-admin.ts you@example.com --remove
 *
 * Admins can move money, review KYC, resolve disputes and flag accounts, so keep
 * this list short and known.
 */
async function main(): Promise<void> {
  const email = process.argv[2];
  const remove = process.argv.includes('--remove');

  if (!email) {
    console.error('Usage: npx tsx scripts/make-admin.ts <email> [--remove]');
    process.exit(1);
  }

  const db = createDatabase();
  try {
    const user = await db
      .selectFrom('users')
      .select(['id', 'email', 'role'])
      .where('email', '=', email)
      .executeTakeFirst();

    if (!user) {
      console.error(`No user found with email: ${email}`);
      process.exit(1);
    }

    const nextRole = remove ? 'user' : 'admin';
    await db
      .updateTable('users')
      .set({ role: nextRole, updated_at: new Date() })
      .where('id', '=', user.id)
      .execute();

    console.log(`✅ ${email} is now role="${nextRole}" (was "${user.role}")`);
  } finally {
    await db.destroy();
  }
}

main().catch((err) => {
  console.error('Failed:', err);
  process.exit(1);
});
