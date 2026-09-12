import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError } from '@/utils/helpers';
import { config } from '@/config/env';
import { recordAudit, actorFromRequest } from '@/services/audit';
import { recordNotification } from '@/services/notify';
import { runKycCheck } from '@/services/kyc-check';

const kycSubmitSchema = z.object({
  document_type: z.enum(['passport', 'id_card']),
  document_id: z.string().min(3),
  /** As printed on the document — may differ from the account's own full_name (nicknames, married names), so an admin needs to see both. */
  first_name: z.string().min(1),
  last_name: z.string().min(1),
  address: z.string().min(3),
  document_photo_url: z.string().url(),
  /** Photo of the user holding the document, for the AI face-match check. */
  selfie_photo_url: z.string().url(),
});

const kycReviewSchema = z.object({
  user_id: z.string().uuid(),
  status: z.enum(['approved', 'rejected', 'pending']),
});

export async function registerComplianceRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>('/api/compliance/kyc/submit', async (request, reply) => {
    const parsed = kycSubmitSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'compliance.invalidKycSubmission');
    }

    const userId = request.userId;
    if (!userId) {
      throw new AppError('AUTH_ERROR', 401, 'common.authRequired');
    }

    const user = await request.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', userId)
      .executeTakeFirst();

    if (!user) {
      throw new AppError('NOT_FOUND', 404, 'common.userNotFound');
    }

    const now = new Date();
    await request.db
      .updateTable('users')
      .set({
        kyc_status: 'pending',
        kyc_document_type: parsed.data.document_type,
        kyc_document_id: parsed.data.document_id,
        kyc_first_name: parsed.data.first_name,
        kyc_last_name: parsed.data.last_name,
        kyc_address: parsed.data.address,
        kyc_document_photo_url: parsed.data.document_photo_url,
        kyc_selfie_photo_url: parsed.data.selfie_photo_url,
        // A fresh submission invalidates whatever the previous AI pass said.
        kyc_ai_analysis: null,
        kyc_ai_risk: null,
        kyc_submitted_at: now,
        updated_at: now,
      })
      .where('id', '=', user.id)
      .execute();

    await recordAudit(request.db, actorFromRequest(request), {
      action: 'kyc.submit',
      targetType: 'user',
      targetId: user.id,
      summary: `KYC documents submitted for review (${parsed.data.document_type})`,
      metadata: {
        document_type: parsed.data.document_type,
        document_id: parsed.data.document_id,
        first_name: parsed.data.first_name,
        last_name: parsed.data.last_name,
      },
    });

    await recordNotification(request.db, { userId: user.id, type: 'kyc_submitted', params: {} });

    // Advisory cross-check (matches submitted fields against the document,
    // and the selfie against the document photo) for the admin queue — runs
    // after the response for the real model so submission latency isn't
    // affected; the mock is instant and deterministic, so tests await it
    // directly, same pattern as the receipt/chat-moderation checks.
    const check = runKycCheck(request.db, {
      id: user.id,
      full_name: user.full_name,
      kyc_document_type: parsed.data.document_type,
      kyc_document_photo_url: parsed.data.document_photo_url,
      kyc_selfie_photo_url: parsed.data.selfie_photo_url,
      kyc_first_name: parsed.data.first_name,
      kyc_last_name: parsed.data.last_name,
      kyc_document_id: parsed.data.document_id,
      kyc_address: parsed.data.address,
    });
    if (config.aiKycCheck === 'claude') {
      void check.catch(() => undefined);
    } else {
      await check;
    }

    reply.status(201).send({
      success: true,
      data: { user_id: user.id, kyc_status: 'pending' },
      code: 'KYC_SUBMITTED',
    });
  });

  app.post<{ Body: unknown }>('/api/compliance/kyc/approve', async (request, reply) => {
    const parsed = kycReviewSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'common.invalidKycReviewPayload');
    }

    const user = await request.db
      .selectFrom('users')
      .selectAll()
      .where('id', '=', parsed.data.user_id)
      .executeTakeFirst();

    if (!user) {
      throw new AppError('NOT_FOUND', 404, 'common.userNotFound');
    }

    await request.db
      .updateTable('users')
      .set({ kyc_status: parsed.data.status, updated_at: new Date() })
      .where('id', '=', user.id)
      .execute();

    if (parsed.data.status === 'approved' || parsed.data.status === 'rejected') {
      await recordNotification(request.db, {
        userId: user.id,
        type: 'kyc_reviewed',
        params: { _variant: parsed.data.status },
      });
    }

    reply.send({
      success: true,
      data: { user_id: user.id, kyc_status: parsed.data.status },
      code: 'KYC_REVIEWED',
    });
  });
}
