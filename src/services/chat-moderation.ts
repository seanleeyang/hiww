import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { getChatModerationAnalyzer } from '@/services/ai';
import { recordAudit } from '@/services/audit';

const LEAK_PATTERNS: Array<{ re: RegExp; reason: string }> = [
  { re: /\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/, reason: 'possible phone number' },
  { re: /\b\d{9,}\b/, reason: 'possible phone number' },
  { re: /[\w.+-]+@[\w-]+\.[a-z]{2,}/i, reason: 'email address' },
  {
    re: /\b(whatsapp|line id|telegram|wechat|signal app|@[a-z0-9_]{3,})\b/i,
    reason: 'mentions an outside messaging app',
  },
  {
    re: /\b(pay(ment)?\s*(me|directly|outside)|cash only|skip the app|off[- ]platform|outside (of )?the app)\b/i,
    reason: 'suggests paying outside the app',
  },
];

export interface MessageLeakCheck {
  flagged: boolean;
  reasons: string[];
}

/**
 * Instant, free, deterministic pattern match — catches the obvious leakage
 * attempts (contact info, off-platform payment) before the message is even
 * stored. Runs synchronously on every send; the subtler cases (harassment,
 * indirect phrasing) are left to the async AI pass below.
 */
export function checkMessageLeakage(body: string): MessageLeakCheck {
  const reasons = new Set<string>();
  for (const { re, reason } of LEAK_PATTERNS) {
    if (re.test(body)) reasons.add(reason);
  }
  return { flagged: reasons.size > 0, reasons: [...reasons] };
}

export const LEAKAGE_WARNING =
  'For your safety, keep item details, payments and contact info inside Hiww. Messages are reviewed for anything that looks unsafe.';

interface MessageForCheck {
  id: string;
  order_id: string;
  body: string;
}

/**
 * Background AI pass. Runs after the message is already stored and the
 * sender's request has returned, so it never adds latency to sending a
 * message — same fire-and-forget shape as the receipt check. Never
 * downgrades a risk the synchronous regex pass already set, only escalates.
 */
export async function runChatModerationCheck(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: Kysely<Database> | any,
  message: MessageForCheck,
  existingRisk: 'medium' | 'high' | null
): Promise<void> {
  if (existingRisk === 'high') return; // already at the top; nothing to escalate

  try {
    const result = await getChatModerationAnalyzer().analyze({ body: message.body });
    if (result.risk === 'low') return;
    if (existingRisk === 'medium' && result.risk === 'medium') return; // no change

    await db
      .updateTable('messages')
      .set({
        flag_risk: result.risk,
        flag_reasons: JSON.stringify(result.reasons),
        flag_summary: result.summary,
      })
      .where('id', '=', message.id)
      .execute();

    await recordAudit(
      db,
      { id: null, role: 'system' },
      {
        action: 'message.flag',
        targetType: 'message',
        targetId: message.id,
        summary: `AI chat check flagged a message on order ${message.order_id} as ${result.risk} risk`,
        metadata: { risk: result.risk, reasons: result.reasons, model: result.model },
      }
    );
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[chat-moderation] failed for message', message.id, err);
  }
}
