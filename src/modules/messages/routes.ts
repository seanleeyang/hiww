import { FastifyInstance } from 'fastify';
import { AppError, generateId } from '@/utils/helpers';
import { messageSchema } from '@/types/schemas';
import { toUserSummary, USER_SUMMARY_COLUMNS } from '@/utils/user-summary';
import { recordAudit, actorFromRequest } from '@/services/audit';
import {
  redactLeakage,
  presentMessageBody,
  leakageWarning,
  qrWarning,
  runChatModerationCheck,
} from '@/services/chat-moderation';
import { detectQrCode } from '@/services/qr-check';
import { recordTyping, isCounterpartyTyping } from '@/services/typing';
import { sendPush } from '@/services/push-notify';
import { config } from '@/config/env';
import { requireOrderParticipant } from '@/utils/order-participant';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function loadOrderForParticipant(request: any, orderId: string): Promise<any> {
  return requireOrderParticipant(request.db, request.userId, orderId, 'common.notPartOfOrder');
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function chatDeletedColumnFor(order: any, userId: string): 'chat_deleted_by_shopper_at' | 'chat_deleted_by_traveler_at' {
  return order.shopper_id === userId ? 'chat_deleted_by_shopper_at' : 'chat_deleted_by_traveler_at';
}

const CHAT_CLOSE_GRACE_MS = 24 * 60 * 60 * 1000;

/**
 * The chat stays open for a 24h grace period after the deal is over — either
 * `delivered` (the shopper and traveler often still need to coordinate right
 * after handover — a missing accessory, a thank-you) or `cancelled` (nothing
 * left to negotiate) — then locks for good. Any other status means there's
 * still an active negotiation/transaction, so the chat never closes.
 * Returns null while the chat isn't closing at all.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function chatClosesAt(order: any): Date | null {
  const endedAt =
    order.status === 'delivered'
      ? order.delivered_at
      : order.status === 'cancelled'
        ? order.cancelled_at
        : null;
  if (order.status !== 'delivered' && order.status !== 'cancelled') return null;
  // Ended but missing the expected timestamp (shouldn't happen) — treat as
  // already closed rather than leaving the chat open indefinitely.
  if (!endedAt) return new Date(0);
  return new Date(new Date(endedAt).getTime() + CHAT_CLOSE_GRACE_MS);
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function isChatClosed(order: any): boolean {
  const closesAt = chatClosesAt(order);
  return closesAt !== null && Date.now() >= closesAt.getTime();
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
    async (request, reply) => {
      const order = await loadOrderForParticipant(request, request.params.id);

      // Deleting a closed chat only hides it from the deleter's own view —
      // the other party's copy, and the underlying rows, are untouched.
      const deletedAt = order[chatDeletedColumnFor(order, request.userId!)];
      if (deletedAt) {
        reply.send({
          success: true,
          data: { items: [], counterparty_typing: false, closed: true, deleted: true },
          code: 'MESSAGES_LISTED',
        });
        return;
      }

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

      const locale = request.locale ?? 'en';
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const items = rows.map(({ hidden_at, image_url, ...row }: any) => ({
        ...row,
        body: presentMessageBody({ ...row, hidden_at }, request.userId!, locale),
        image_url: hidden_at ? null : image_url,
      }));

      const closesAt = chatClosesAt(order);
      reply.send({
        success: true,
        data: {
          items,
          counterparty_typing: isCounterpartyTyping(request.params.id, request.userId!),
          closed: isChatClosed(order),
          closes_at: closesAt && closesAt.getTime() > Date.now() ? closesAt.toISOString() : null,
          deleted: false,
        },
        code: 'MESSAGES_LISTED',
      });
    }
  );

  app.post<{ Params: { id: string }; Body: unknown }>(
    '/api/orders/:id/messages',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request, reply) => {
      const parsed = messageSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'messages.invalidBody');
      }
      const order = await loadOrderForParticipant(request, request.params.id);
      // A 24h grace period after delivery, then the conversation locks.
      if (isChatClosed(order)) {
        throw new AppError('INVALID_STATUS', 409, 'messages.chatClosed');
      }

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
          sender_id: request.userId!,
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

      // Chat isn't recorded in the notifications feed (Inbox already has its
      // own Messages tab), but it gets the same "hard" push everything else
      // does — a reply while the app is closed is exactly what push exists
      // for. Best-effort, uses the already-redacted body.
      const recipientId = order.shopper_id === request.userId ? order.traveler_id : order.shopper_id;
      await sendPush(request.db, recipientId, {
        title: `New message about "${order.item_description}"`,
        body: leak.body ? leak.body.slice(0, 120) : 'Sent a photo',
        data: { link: `/orders/${request.params.id}/chat` },
      });

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
          sender_id: request.userId!,
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

      const locale = request.locale ?? 'en';
      reply.status(201).send({
        success: true,
        data: {
          id,
          warning: qrFound ? qrWarning(locale) : leak.flagged ? leakageWarning(locale) : null,
        },
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
    async (request, reply) => {
      await loadOrderForParticipant(request, request.params.id);
      recordTyping(request.params.id, request.userId!);
      reply.send({ success: true, data: { ok: true }, code: 'TYPING_RECORDED' });
    }
  );

  app.post<{ Params: { id: string } }>(
    '/api/orders/:id/messages/read',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request, reply) => {
      await loadOrderForParticipant(request, request.params.id);

      await request.db
        .updateTable('messages')
        .set({ read_at: new Date() })
        .where('order_id', '=', request.params.id)
        .where('sender_id', '!=', request.userId!)
        .where('read_at', 'is', null)
        .execute();

      reply.send({ success: true, data: { ok: true }, code: 'MESSAGES_READ' });
    }
  );

  // Hide a closed chat from the caller's own inbox/view. Only sets the
  // caller's own timestamp — never touches the other party's copy or the
  // message rows themselves, which stay intact for dispute/support
  // reference. Only available once the chat is actually closed (delivered).
  app.post<{ Params: { id: string } }>(
    '/api/orders/:id/messages/delete-chat',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request, reply) => {
      const order = await loadOrderForParticipant(request, request.params.id);
      if (!isChatClosed(order)) {
        throw new AppError('INVALID_STATUS', 409, 'messages.chatNotYetClosed');
      }

      await request.db
        .updateTable('orders')
        .set({ [chatDeletedColumnFor(order, request.userId!)]: new Date(), updated_at: new Date() })
        .where('id', '=', request.params.id)
        .execute();

      reply.send({ success: true, data: { ok: true }, code: 'CHAT_DELETED' });
    }
  );

  // Every order the caller is in that has at least one message.
  app.get(
    '/api/inbox',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request, reply) => {
      const orders = await request.db
        .selectFrom('orders')
        .select([
          'id',
          'shopper_id',
          'traveler_id',
          'item_description',
          'status',
          'chat_deleted_by_shopper_at',
          'chat_deleted_by_traveler_at',
        ])
        .where((eb: any) =>
          eb.or([eb('shopper_id', '=', request.userId), eb('traveler_id', '=', request.userId)])
        )
        .execute();

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const threads: any[] = [];
      for (const order of orders) {
        if (order[chatDeletedColumnFor(order, request.userId!)]) continue;

        const last = await request.db
          .selectFrom('messages')
          .select(['id', 'sender_id', 'body', 'image_url', 'hidden_at', 'created_at'])
          .where('order_id', '=', order.id)
          .orderBy('created_at', 'desc')
          .limit(1)
          .executeTakeFirst();
        if (!last) continue;
        const { hidden_at, ...lastPublic } = last;
        lastPublic.body = presentMessageBody({ ...last, hidden_at }, request.userId!, request.locale ?? 'en');
        if (hidden_at) lastPublic.image_url = null;

        const unread = await request.db
          .selectFrom('messages')
          .select((eb) => eb.fn.count('id').as('count'))
          .where('order_id', '=', order.id)
          .where('sender_id', '!=', request.userId!)
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
