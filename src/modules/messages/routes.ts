import { FastifyInstance } from 'fastify';
import { AppError, generateId } from '@/utils/helpers';
import { messageSchema } from '@/types/schemas';
import { toUserSummary, USER_SUMMARY_COLUMNS } from '@/utils/user-summary';
import { recordAudit, actorFromRequest } from '@/services/audit';
import {
  redactLeakage,
  presentMessageBody,
  LEAKAGE_WARNING,
  QR_WARNING,
  runChatModerationCheck,
} from '@/services/chat-moderation';
import { detectQrCode } from '@/services/qr-check';
import { recordTyping, isCounterpartyTyping } from '@/services/typing';
import { config } from '@/config/env';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function loadOrderForParticipant(request: any, orderId: string): Promise<any> {
  const order = await request.db
    .selectFrom('orders')
    .selectAll()
    .where('id', '=', orderId)
    .executeTakeFirst();

  if (!order) {
    throw new AppError('NOT_FOUND', 404, 'Order not found');
  }
  if (order.shopper_id !== request.userId && order.traveler_id !== request.userId) {
    throw new AppError('FORBIDDEN', 403, 'You are not part of this order');
  }
  return order;
}

/**
 * Order-scoped messaging. A conversation is every message with the same
 * `order_id`; the inbox groups by order. Poll-based — no websockets in the pilot.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerMessagesRoutes(app: FastifyInstance): Promise<void> {
  app.get<{ Params: { id: string } }>(
    '/api/orders/:id/messages',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      await loadOrderForParticipant(request, request.params.id);

      const rows = await request.db
        .selectFrom('messages')
        .innerJoin('users as sender', 'sender.id', 'messages.sender_id')
        .select([
          'messages.id',
          'messages.sender_id',
          'messages.body',
          'messages.image_url',
          'messages.hidden_at',
          'messages.created_at',
          'messages.read_at',
          'sender.full_name as sender_name',
        ])
        .where('messages.order_id', '=', request.params.id)
        .orderBy('messages.created_at', 'asc')
        .execute();

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const items = rows.map(({ hidden_at, image_url, ...row }: any) => ({
        ...row,
        body: presentMessageBody({ ...row, hidden_at }, request.userId),
        image_url: hidden_at ? null : image_url,
      }));

      reply.send({
        success: true,
        data: {
          items,
          counterparty_typing: isCounterpartyTyping(request.params.id, request.userId),
        },
        code: 'MESSAGES_LISTED',
      });
    }
  );

  app.post<{ Params: { id: string }; Body: unknown }>(
    '/api/orders/:id/messages',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = messageSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Provide a message or a photo');
      }
      await loadOrderForParticipant(request, request.params.id);

      const id = generateId();

      // Redact contact info / off-platform-payment mentions in place — the
      // raw text is never stored, so it can't leak even briefly.
      const leak = redactLeakage(parsed.data.body ?? '');
      const reasons = [...leak.reasons];
      let flagged = leak.flagged;

      // A photo containing a QR code is rejected outright rather than just
      // flagged — there's rarely a legitimate reason to send one in order
      // chat, and unlike text there's no clean way to redact just the QR
      // out of an image. The raw URL only ever lands in the audit log.
      let imageUrl: string | null = parsed.data.image_url ?? null;
      let qrFound = false;
      if (imageUrl) {
        const qr = await detectQrCode(imageUrl);
        if (qr.found) {
          qrFound = true;
          flagged = true;
          reasons.push(qr.reason ?? 'contains a QR code');
          await recordAudit(request.db, actorFromRequest(request), {
            action: 'message.flag',
            targetType: 'message',
            targetId: id,
            summary: `Photo on order ${request.params.id} rejected — looked like ${qr.reason}`,
            metadata: { risk: 'medium', reason: qr.reason, original_image_url: imageUrl, payload: qr.payload },
          });
          imageUrl = null;
        }
      }

      await request.db
        .insertInto('messages')
        .values({
          id,
          order_id: request.params.id,
          sender_id: request.userId,
          body: leak.body,
          image_url: imageUrl,
          created_at: new Date(),
          flag_risk: flagged ? 'medium' : null,
          flag_reasons: flagged ? JSON.stringify(reasons) : null,
        })
        .execute();

      if (leak.flagged) {
        await recordAudit(request.db, actorFromRequest(request), {
          action: 'message.flag',
          targetType: 'message',
          targetId: id,
          summary: `Message on order ${request.params.id} redacted by pattern check: ${leak.reasons.join(', ')}`,
          metadata: { risk: 'medium', reasons: leak.reasons, original_body: parsed.data.body },
        });
      }

      // Runs after the response so it never slows down sending. Checks the
      // already-redacted text and, if present, the photo (never a QR photo —
      // those never make it past the check above). The mock analyzer is
      // instant and deterministic, so tests await it directly; the real
      // model takes a moment and runs in the background.
      const moderation = runChatModerationCheck(
        request.db,
        {
          id,
          order_id: request.params.id,
          sender_id: request.userId,
          body: leak.body,
          image_url: imageUrl,
        },
        flagged ? 'medium' : null
      );
      if (config.aiChatModeration === 'claude') {
        void moderation.catch(() => undefined);
      } else {
        await moderation;
      }

      reply.status(201).send({
        success: true,
        data: { id, warning: qrFound ? QR_WARNING : leak.flagged ? LEAKAGE_WARNING : null },
        code: 'MESSAGE_SENT',
      });
    }
  );

  // Fire-and-forget heartbeat while composing — the counterparty picks it up
  // on their next poll of GET .../messages (`counterparty_typing`). No
  // response body needed; the sender doesn't care whether this succeeds.
  app.post<{ Params: { id: string } }>(
    '/api/orders/:id/typing',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      await loadOrderForParticipant(request, request.params.id);
      recordTyping(request.params.id, request.userId);
      reply.send({ success: true, data: { ok: true }, code: 'TYPING_RECORDED' });
    }
  );

  app.post<{ Params: { id: string } }>(
    '/api/orders/:id/messages/read',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      await loadOrderForParticipant(request, request.params.id);

      await request.db
        .updateTable('messages')
        .set({ read_at: new Date() })
        .where('order_id', '=', request.params.id)
        .where('sender_id', '!=', request.userId)
        .where('read_at', 'is', null)
        .execute();

      reply.send({ success: true, data: { ok: true }, code: 'MESSAGES_READ' });
    }
  );

  // Every order the caller is in that has at least one message.
  app.get(
    '/api/inbox',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const orders = await request.db
        .selectFrom('orders')
        .select(['id', 'shopper_id', 'traveler_id', 'item_description', 'status'])
        .where((eb: any) =>
          eb.or([eb('shopper_id', '=', request.userId), eb('traveler_id', '=', request.userId)])
        )
        .execute();

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const threads: any[] = [];
      for (const order of orders) {
        const last = await request.db
          .selectFrom('messages')
          .select(['id', 'sender_id', 'body', 'image_url', 'hidden_at', 'created_at'])
          .where('order_id', '=', order.id)
          .orderBy('created_at', 'desc')
          .limit(1)
          .executeTakeFirst();
        if (!last) continue;
        const { hidden_at, ...lastPublic } = last;
        lastPublic.body = presentMessageBody({ ...last, hidden_at }, request.userId);
        if (hidden_at) lastPublic.image_url = null;

        const unread = await request.db
          .selectFrom('messages')
          .select((eb: any) => eb.fn.count('id').as('count'))
          .where('order_id', '=', order.id)
          .where('sender_id', '!=', request.userId)
          .where('read_at', 'is', null)
          .executeTakeFirst();

        const counterpartyId =
          order.shopper_id === request.userId ? order.traveler_id : order.shopper_id;
        const counterparty = await request.db
          .selectFrom('users')
          .select([...USER_SUMMARY_COLUMNS])
          .where('id', '=', counterpartyId)
          .executeTakeFirst();

        threads.push({
          order_id: order.id,
          item_description: order.item_description,
          order_status: order.status,
          counterparty: counterparty ? toUserSummary(counterparty) : null,
          last_message: lastPublic,
          unread_count: Number(unread?.count ?? 0),
        });
      }

      threads.sort(
        (a, b) =>
          new Date(b.last_message.created_at).getTime() -
          new Date(a.last_message.created_at).getTime()
      );

      reply.send({ success: true, data: { items: threads }, code: 'INBOX' });
    }
  );
}
