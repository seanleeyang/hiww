import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { getKycAnalyzer } from '@/services/ai';
import { recordAudit } from '@/services/audit';

interface UserForKycCheck {
  id: string;
  kyc_document_type: 'passport' | 'id_card' | 'drivers_license';
  kyc_document_photo_url: string;
  kyc_document_photo_back_url?: string | null;
  kyc_selfie_photo_url: string;
  kyc_first_name: string;
  kyc_last_name: string;
  kyc_document_id: string;
  kyc_address: string;
}

/**
 * Run the AI KYC check for one user's submission and persist the result.
 * Best-effort: a failure here must never block the submission itself (the
 * row is already saved as `pending`) — everything is wrapped and only
 * logged, same shape as {@link runReceiptCheck}.
 *
 * Never sets `kyc_status` — this is advisory context for the admin review
 * queue, not an auto-approve/reject. A `medium`/`high` result is also
 * audited so it's discoverable outside the queue too.
 */
export async function runKycCheck(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: Kysely<Database> | any,
  user: UserForKycCheck
): Promise<void> {
  try {
    const analysis = await getKycAnalyzer().analyze({
      documentType: user.kyc_document_type,
      documentPhotoUrl: user.kyc_document_photo_url,
      documentPhotoBackUrl: user.kyc_document_photo_back_url,
      selfiePhotoUrl: user.kyc_selfie_photo_url,
      submittedFirstName: user.kyc_first_name,
      submittedLastName: user.kyc_last_name,
      submittedDocumentId: user.kyc_document_id,
      submittedAddress: user.kyc_address,
    });

    await db
      .updateTable('users')
      .set({ kyc_ai_analysis: analysis, kyc_ai_risk: analysis.risk, updated_at: new Date() })
      .where('id', '=', user.id)
      .execute();

    if (analysis.risk !== 'low') {
      await recordAudit(db, { id: null, role: 'system' }, {
        action: 'kyc.ai_flag',
        targetType: 'user',
        targetId: user.id,
        summary: `AI KYC check flagged submission for ${user.id} as ${analysis.risk} risk`,
        metadata: { risk: analysis.risk, flags: analysis.flags, model: analysis.model },
      });
    }
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[kyc-check] failed for user', user.id, err);
    // Mirror to the audit trail (visible in the admin console's Audit tab)
    // so a persistently failing check is actually discoverable — otherwise
    // it silently degrades to no AI assessment with no visible sign.
    await recordAudit(db, { id: null, role: 'system' }, {
      action: 'kyc.ai_check_failed',
      targetType: 'user',
      targetId: user.id,
      summary: `AI KYC check failed for ${user.id}: ${err instanceof Error ? err.message : String(err)}`,
      metadata: { error: err instanceof Error ? err.message : String(err) },
    });
  }
}
