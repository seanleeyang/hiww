import crypto from 'crypto';
import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { generateId } from '@/utils/helpers';
import { getOtpSender } from './provider';
import type { OtpChannel } from './types';

const OTP_TTL_MINUTES = 10;

function generateCode(): string {
  return crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
}

/**
 * Issues a fresh code for one channel, invalidating any earlier unconsumed
 * one for the same user+channel, and sends it (mock or real, see
 * `getOtpSender`). Returns the plaintext code — callers only echo it back to
 * the client (`debug_otp`) while `isMockOtp()` is true.
 */
export async function issueOtp(
  db: Kysely<Database>,
  userId: string,
  channel: OtpChannel,
  destination: string
): Promise<string> {
  const code = generateCode();
  const now = new Date();

  await db.deleteFrom('otp_codes').where('user_id', '=', userId).where('channel', '=', channel).execute();
  await db
    .insertInto('otp_codes')
    .values({
      id: generateId(),
      user_id: userId,
      channel,
      code,
      expires_at: new Date(now.getTime() + OTP_TTL_MINUTES * 60_000),
      created_at: now,
    })
    .execute();

  const sender = getOtpSender();
  if (channel === 'email') {
    await sender.sendEmailOtp(destination, code);
  } else {
    await sender.sendSmsOtp(destination, code);
  }

  return code;
}

/**
 * Checks a submitted code against the latest unconsumed, unexpired one for
 * this user+channel. On success, consumes it and stamps
 * `users.<channel>_verified_at`.
 */
export async function verifyOtp(
  db: Kysely<Database>,
  userId: string,
  channel: OtpChannel,
  code: string
): Promise<boolean> {
  const now = new Date();
  const row = await db
    .selectFrom('otp_codes')
    .selectAll()
    .where('user_id', '=', userId)
    .where('channel', '=', channel)
    .where('code', '=', code)
    .where('consumed_at', 'is', null)
    .where('expires_at', '>', now)
    .executeTakeFirst();

  if (!row) return false;

  await db.updateTable('otp_codes').set({ consumed_at: now }).where('id', '=', row.id).execute();
  if (channel === 'email') {
    await db.updateTable('users').set({ email_verified_at: now, updated_at: now }).where('id', '=', userId).execute();
  } else {
    await db.updateTable('users').set({ phone_verified_at: now, updated_at: now }).where('id', '=', userId).execute();
  }

  return true;
}
