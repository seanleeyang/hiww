import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { generateId } from '@/utils/helpers';

/**
 * Canonical action names. Keep these stable — the operator console and any
 * reconciliation query filter on them.
 */
export type AuditAction =
  | 'order.create'
  | 'order.payment_claim'
  | 'payment.confirm'
  | 'order.purchase_proof'
  | 'order.receipt_flag'
  | 'order.receipt_flag_cleared'
  | 'order.ship'
  | 'order.release'
  | 'order.payout'
  | 'dispute.open'
  | 'dispute.resolve'
  | 'kyc.review'
  | 'user.flag'
  | 'message.flag'
  | 'message.flag_cleared'
  | 'message.check_failed'
  | 'order.receipt_check_failed'
  | 'trip.update'
  | 'trip.cancel'
  | 'trip.remove_by_admin'
  | 'request.update'
  | 'request.cancel'
  | 'request.remove_by_admin';

export interface AuditActor {
  id?: string | null;
  role?: string | null;
}

export interface AuditInput {
  action: AuditAction;
  targetType: 'order' | 'user' | 'dispute' | 'message' | 'trip' | 'request';
  targetId: string;
  summary: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  metadata?: Record<string, any>;
}

/**
 * Append one row to the audit log. Best-effort: a logging failure must never
 * break the action it is recording, so callers `await` it but errors are
 * swallowed with a console warning.
 *
 * Pass the same `db`/`trx` the action ran on so the entry commits atomically
 * with it where a transaction is in play.
 */
export async function recordAudit(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: Kysely<Database> | any,
  actor: AuditActor,
  input: AuditInput
): Promise<void> {
  try {
    await db
      .insertInto('audit_log')
      .values({
        id: generateId(),
        actor_id: actor.id ?? null,
        actor_role: actor.role ?? null,
        action: input.action,
        target_type: input.targetType,
        target_id: input.targetId,
        summary: input.summary,
        // node-postgres JSON.stringifies a plain object for a jsonb parameter.
        metadata: input.metadata ?? {},
        created_at: new Date(),
      })
      .execute();
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[audit] failed to record', input.action, input.targetId, err);
  }
}

/** Pull the actor out of a Fastify request the auth guard has populated. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function actorFromRequest(request: any): AuditActor {
  return { id: request.userId ?? null, role: request.userRole ?? null };
}
