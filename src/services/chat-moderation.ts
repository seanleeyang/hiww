import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { getChatModerationAnalyzer } from '@/services/ai';
import { recordAudit } from '@/services/audit';

const LEAK_PATTERNS: Array<{ re: RegExp; reason: string; placeholder: string }> = [
  {
    // A run of 9+ digits with any single-character separators (dash, dot,
    // space) interspersed anywhere — covers phone numbers, PromptPay numbers
    // (which are just a Thai phone number), and bank account numbers in
    // whatever grouping someone types them in (e.g. "123-4-56789-0"), not
    // just the 3-3-4 phone shape.
    re: /\b\d(?:[-.\s]?\d){8,}\b/g,
    reason: 'possible phone/account number',
    placeholder: '[number hidden]',
  },
  {
    re: /\b(prompt\s*pay|promptpay|bank\s*(?:account|transfer|details)|account\s*number|acc(?:ount)?\.?\s*no\.?|swift\s*code|iban)\b/gi,
    reason: 'mentions bank/PromptPay payment details',
    placeholder: '[hidden]',
  },
  { re: /[\w.+-]+@[\w-]+\.[a-z]{2,}/gi, reason: 'email address', placeholder: '[email hidden]' },
  {
    // Named apps as standalone words — "line" alone is ambiguous English, but
    // catching it is worth the occasional false positive (a redaction is
    // cheap; a missed leakage attempt isn't).
    re: /\b(whatsapp|line|telegram|wechat|kakao(?:talk)?|viber|signal(?:\s*app)?|messenger|discord|snapchat|instagram)\b/gi,
    reason: 'mentions an outside messaging app',
    placeholder: '[hidden]',
  },
  {
    // `@handle` mentions. No leading `\b` — it can't match right before `@`
    // when preceded by whitespace (both sides are non-word characters, so
    // there's no word/non-word transition for `\b` to anchor on).
    re: /@[\w.]{2,}/g,
    reason: 'mentions a social/messaging handle',
    placeholder: '[hidden]',
  },
  {
    re: /\b(pay(ment)?\s*(me|directly|outside)|cash only|skip the app|off[- ]platform|outside (of )?the app)\b/gi,
    reason: 'suggests paying outside the app',
    placeholder: '[hidden]',
  },
];

export interface MessageRedaction {
  /** The text to actually store/show — contact info etc. replaced with a placeholder. */
  body: string;
  flagged: boolean;
  reasons: string[];
}

/**
 * Instant, free, deterministic pattern match — redacts the obvious leakage
 * attempts (contact info, off-platform payment) in place before the message
 * is ever stored, so the raw phone number / email / handle is never exposed
 * to the other party even briefly. Runs synchronously on every send; the
 * subtler cases (harassment, indirect phrasing) are left to the async AI
 * pass below, which can't redact — see `runChatModerationCheck`.
 */
export function redactLeakage(body: string): MessageRedaction {
  const reasons = new Set<string>();
  let redacted = body;
  for (const { re, reason, placeholder } of LEAK_PATTERNS) {
    if (re.test(redacted)) reasons.add(reason);
    redacted = redacted.replace(re, placeholder);
  }
  return { body: redacted, flagged: reasons.size > 0, reasons: [...reasons] };
}

export const LEAKAGE_WARNING =
  "We removed contact details or off-platform payment mentions from your message to keep everyone safe — the rest still sent. Messages are reviewed for anything else that looks unsafe.";

export const QR_WARNING =
  "We removed a QR code from your photo — sharing payment or contact QR codes isn't allowed here. Messages are reviewed for anything else that looks unsafe.";

/** Shown in place of a message an operator or the AI check pulled after the fact. */
export const HIDDEN_TO_SENDER =
  "Your message was removed — it didn't meet Hiww's chat guidelines and is under review.";
export const HIDDEN_TO_OTHERS = "A message was removed — it didn't meet Hiww's chat guidelines.";

/** What a participant should see instead of the raw body, if anything. */
export function presentMessageBody(
  message: { body: string; hidden_at?: Date | string | null; sender_id: string },
  viewerId: string
): string {
  if (!message.hidden_at) return message.body;
  return message.sender_id === viewerId ? HIDDEN_TO_SENDER : HIDDEN_TO_OTHERS;
}

interface MessageForCheck {
  id: string;
  order_id: string;
  body: string;
}

/**
 * Background AI pass. Runs after the message is already stored (with any
 * regex redaction already applied) and the sender's request has returned,
 * so it never adds latency to sending — same fire-and-forget shape as the
 * receipt check. A `high` verdict retroactively hides the message (an
 * operator can still see it in the review queue); `medium` only flags it,
 * since confidence is lower and hiding real conversation is costlier than
 * the residual risk. Never downgrades a risk the regex pass already set.
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
        ...(result.risk === 'high' ? { hidden_at: new Date() } : {}),
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
        summary:
          result.risk === 'high'
            ? `AI chat check hid a message on order ${message.order_id} (high risk)`
            : `AI chat check flagged a message on order ${message.order_id} as ${result.risk} risk`,
        metadata: { risk: result.risk, reasons: result.reasons, model: result.model },
      }
    );
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[chat-moderation] failed for message', message.id, err);
  }
}
