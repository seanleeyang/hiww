import { Kysely } from 'kysely';
// Relative, not the `@/` alias — Jest's globalSetup (tests/global-setup.ts)
// imports migrations/list.ts through a loader that doesn't apply the
// alias's moduleNameMapper, unlike every normal test file or the real
// migration runner (migrations/run.ts, run via tsx).
import { encryptSecret, isEncryptedSecret } from '../src/utils/encryption';

/**
 * One-time backfill: encrypts any `bank_account_number` still sitting in
 * plaintext on `users` or `payouts` (see src/utils/encryption.ts for why —
 * account numbers were stored as plain readable text before this). Safe to
 * run more than once: `isEncryptedSecret` skips rows already handled, so a
 * re-run (or running against a database that already went through this)
 * touches nothing.
 *
 * Going forward, `PATCH /api/me` encrypts on write and the payout route
 * copies the already-encrypted value straight through — this migration only
 * catches whatever was written before that existed.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function up(db: Kysely<any>): Promise<void> {
  const users = await db
    .selectFrom('users')
    .select(['id', 'bank_account_number'])
    .where('bank_account_number', 'is not', null)
    .execute();
  for (const user of users) {
    if (isEncryptedSecret(user.bank_account_number)) continue;
    await db
      .updateTable('users')
      .set({ bank_account_number: encryptSecret(user.bank_account_number) })
      .where('id', '=', user.id)
      .execute();
  }

  const payouts = await db
    .selectFrom('payouts')
    .select(['id', 'bank_account_number'])
    .where('bank_account_number', 'is not', null)
    .execute();
  for (const payout of payouts) {
    if (isEncryptedSecret(payout.bank_account_number)) continue;
    await db
      .updateTable('payouts')
      .set({ bank_account_number: encryptSecret(payout.bank_account_number) })
      .where('id', '=', payout.id)
      .execute();
  }
}

// Deliberately no down() — decrypting back to plaintext on rollback would
// defeat the point; a rollback here means re-deploying without the
// encrypt/decrypt code, which still works fine (decryptSecret's legacy
// passthrough only helps going forward, but old plaintext rows are also
// still readable as plaintext by anything that doesn't know about
// encryption at all).
