import { makeTestApp, closeTestApp, createUser, type TestContext } from '../helpers/test-app';
import { up as encryptBankAccountNumbers } from '../../migrations/047_encrypt_bank_account_numbers';

/**
 * migrations/047_encrypt_bank_account_numbers.ts already ran once as part of
 * the test database's own setup (tests/global-setup.ts runs every migration
 * up front) — against an empty users/payouts table at the time, so there was
 * nothing to backfill. This exercises the actual backfill logic directly:
 * seed a plaintext value the way it would have existed before encryption was
 * added, run the migration's `up` again, and confirm it catches it — and
 * that running it yet again afterwards is a safe no-op.
 */
describe('047_encrypt_bank_account_numbers backfill', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
  });

  it('encrypts a plaintext bank_account_number left over from before encryption existed', async () => {
    const user = await createUser(ctx, { user_type: 'traveler' });
    await ctx.db
      .updateTable('users')
      .set({ bank_account_number: '1234567890' })
      .where('id', '=', user.userId)
      .execute();

    await encryptBankAccountNumbers(ctx.db);

    const row = await ctx.db
      .selectFrom('users')
      .select('bank_account_number')
      .where('id', '=', user.userId)
      .executeTakeFirst();
    expect(row?.bank_account_number).toMatch(/^enc:v1:/);
    expect(row?.bank_account_number).not.toContain('1234567890');

    // Running it again doesn't double-encrypt (which would make the value
    // undecryptable back to the original digits).
    await encryptBankAccountNumbers(ctx.db);
    const again = await ctx.db
      .selectFrom('users')
      .select('bank_account_number')
      .where('id', '=', user.userId)
      .executeTakeFirst();
    expect(again?.bank_account_number).toBe(row?.bank_account_number);
  });
});
