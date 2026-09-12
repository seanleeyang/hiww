import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { AppError, generateId } from '@/utils/helpers';
import { recordAudit, type AuditActor } from '@/services/audit';
import { recordNotification } from '@/services/notify';

const SUSPENSION_DAYS = 7;

export interface ViolationResult {
  id: string;
  count: number;
  riskStatus: 'flagged' | 'restricted';
  suspendedUntil: Date | null;
}

/**
 * Logs one admin-issued strike against a user and auto-escalates based on
 * the running total — see migration 048 for the full 1st/2nd/3rd shape.
 * Reuses the existing `risk_status`/`token_version` machinery rather than
 * inventing a parallel one: 'restricted' + a bumped token_version is
 * already what an immediate manual ban does (see admin/actions.ts's
 * flag-a-user action); this just adds the strike count that decides *when*
 * to reach for it automatically, plus a `suspended_until` end date for the
 * one escalation step (2nd strike) that isn't permanent.
 */
export async function recordViolation(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: Kysely<Database> | any,
  input: { userId: string; reason: string; actor: AuditActor }
): Promise<ViolationResult> {
  const { userId, reason, actor } = input;
  const id = generateId();
  const now = new Date();

  await db.insertInto('user_violations').values({ id, user_id: userId, reason, issued_by: actor.id ?? null, created_at: now }).execute();

  const { count } = await db
    .selectFrom('user_violations')
    .select((eb: any) => eb.fn.countAll().as('count'))
    .where('user_id', '=', userId)
    .executeTakeFirstOrThrow();
  const total = Number(count);

  let riskStatus: 'flagged' | 'restricted';
  let suspendedUntil: Date | null;
  if (total === 1) {
    riskStatus = 'flagged';
    suspendedUntil = null;
  } else if (total === 2) {
    riskStatus = 'restricted';
    suspendedUntil = new Date(now.getTime() + SUSPENSION_DAYS * 24 * 60 * 60 * 1000);
  } else {
    riskStatus = 'restricted';
    suspendedUntil = null; // Permanent — 3rd strike and beyond.
  }

  const user = await db
    .selectFrom('users')
    .select('token_version')
    .where('id', '=', userId)
    .executeTakeFirstOrThrow();

  await db
    .updateTable('users')
    .set({
      risk_status: riskStatus,
      suspended_until: suspendedUntil,
      // A 2nd or 3rd strike locks the account down immediately — any
      // session already signed in dies right away, same as a manual
      // "restrict" (see admin/actions.ts). A 1st-strike warning doesn't
      // sign anyone out.
      ...(riskStatus === 'restricted' ? { token_version: user.token_version + 1 } : {}),
      updated_at: now,
    })
    .where('id', '=', userId)
    .execute();

  await recordAudit(db, actor, {
    action: 'user.violation',
    targetType: 'user',
    targetId: userId,
    summary: `Violation #${total} logged for user ${userId}: ${reason}${
      riskStatus === 'restricted' ? (suspendedUntil ? ` — suspended until ${suspendedUntil.toISOString()}` : ' — permanently banned') : ' — warned'
    }`,
    metadata: { violation_id: id, count: total, reason, risk_status: riskStatus, suspended_until: suspendedUntil?.toISOString() ?? null },
  });

  const notificationType = total === 1 ? 'account_warned' : total === 2 ? 'account_suspended' : 'account_banned';
  await recordNotification(db, {
    userId,
    type: notificationType,
    params: {
      reason,
      ...(suspendedUntil ? { until: suspendedUntil.toISOString().slice(0, 10) } : {}),
    },
  });

  return { id, count: total, riskStatus, suspendedUntil };
}

/**
 * Blocks issuing a fresh token to a currently-restricted account — called
 * from /api/auth/login and /api/auth/social before signing anything. This
 * is the main place a real user actually sees the "suspended until X" /
 * "permanently banned" message: restricting an account already kills any
 * live session immediately (see recordViolation above), so by the time
 * someone tries to use the app again they're logged out and have to log
 * back in, right into this check.
 */
export function assertNotRestricted(user: { risk_status: string; suspended_until?: Date | null }): void {
  if (user.risk_status !== 'restricted') return;
  if (user.suspended_until && user.suspended_until <= new Date()) return; // Suspension has run its course.

  if (user.suspended_until) {
    throw new AppError('ACCOUNT_RESTRICTED', 403, 'authGuard.accountSuspended', {
      until: user.suspended_until.toISOString().slice(0, 10),
    });
  }
  throw new AppError('ACCOUNT_RESTRICTED', 403, 'authGuard.accountBanned');
}
