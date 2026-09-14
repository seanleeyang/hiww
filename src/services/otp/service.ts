import crypto from 'crypto';
import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { AppError, generateId } from '@/utils/helpers';
import { getOtpSender } from './provider';
import type { OtpChannel } from './types';

const OTP_TTL_MINUTES = 10;

// Per-DESTINATION throttle, independent of `user_id` — without this, an
// attacker who only needs a free email address to create a new account (no
// verification required to sign up) can create unlimited accounts that all
// name the same real victim's phone/email, and every one sends that victim
// a fresh OTP. The per-IP rate limit on the route (see authRouteConfig)
// doesn't stop this: it's the request source that's capped, not the target.
const OTP_DESTINATION_LIMIT = 3;
const OTP_DESTINATION_WINDOW_MINUTES = 60;

function generateCode(): string {
  return crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
}

/**
 * Issues a fresh code for one channel, invalidating any earlier unconsumed
 * one for the same user+channel, and sends it (mock or real, see
 * `getOtpSender`). Returns the plaintext code — callers only echo it back to
 * the client (`debug_otp`) while `isMockOtp()` is true.
 *
 * Throws `AppError('RATE_LIMITED', 429, ...)` if this destination (not just
 * this user) has already received several codes recently, regardless of
 * which account requested them.
 */
export async function issueOtp(
  db: Kysely<Database>,
  userId: string,
  channel: OtpChannel,
  destination: string
): Promise<string> {
  const now = new Date();
  const windowStart = new Date(now.getTime() - OTP_DESTINATION_WINDOW_MINUTES * 60_000);

  const { count } = await db
    .selectFrom('otp_codes')
    .select((eb) => eb.fn.countAll<string>().as('count'))
    .where('channel', '=', channel)
    .where('destination', '=', destination)
    .where('created_at', '>=', windowStart)
    .executeTakeFirstOrThrow();

  if (Number(count) >= OTP_DESTINATION_LIMIT) {
    throw new AppError('RATE_LIMITED', 429, 'otp.tooManyRequests');
  }

  const code = generateCode();

  await db.deleteFrom('otp_codes').where('user_id', '=', userId).where('channel', '=', channel).execute();
  await db
    .insertInto('otp_codes')
    .values({
      id: generateId(),
      user_id: userId,
      channel,
      code,
      destination,
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
