import type { Kysely } from 'kysely';
import type { Database } from '@/types/database';
import { getChatModerationAnalyzer } from '@/services/ai';
import { recordAudit } from '@/services/audit';
import { recordNotification } from '@/services/notify';
import { t } from '@/i18n/messages';
import type { SupportedLocale } from '@/i18n/locale';
import { signPrivateUploadUrl } from '@/utils/signed-url';

// Named social/messaging brands, including short forms (fb, ig, wa) and
// letter-by-letter spelling-out (e.g. "L I N E", "w.a.") as an evasion
// dodge. Each letter is joined by an optional run of space/dot/dash/
// underscore, so "facebook" also matches "f a c e b o o k" or "f.a.c.e.b.o.o.k"
// with the same pattern. Requiring \b at both ends keeps this from firing
// inside ordinary words — e.g. "off by" never matches the "fb" entry because
// the "b" there isn't its own word ("by" continues past it).
const BRAND_NAMES = [
  'whatsapp',
  'wa',
  'line',
  'telegram',
  'wechat',
  'kakaotalk',
  'kakao',
  'viber',
  'signal',
  'messenger',
  'discord',
  'snapchat',
  'instagram',
  'ig',
  'facebook',
  'fb',
];
const spacedLetters = (word: string): string => word.split('').join('[\\s.\\-_]*');
const BRAND_RE = new RegExp(`\\b(?:${BRAND_NAMES.map(spacedLetters).join('|')})\\b`, 'gi');

// Not exhaustive — a baseline of the clearest swear words/slurs and their
// common inflections, spelled out flat (rather than built from a root +
// regex-alternation suffix) so `spacedLetters` can safely split each one
// letter-by-letter without corrupting embedded regex syntax, and so a
// trailing wildcard can't over-match (a `\w*` tail on just the "ass" root
// would also swallow "assassin", "assume", etc. — not a real risk with each
// inflection listed and double-`\b`-anchored individually).
const PROFANITY_EN_WORDS = [
  'fuck',
  'fucking',
  'fucker',
  'fuckers',
  'motherfucker',
  'motherfuckers',
  'shit',
  'shitty',
  'shits',
  'bullshit',
  'bitch',
  'bitches',
  'bitchy',
  'asshole',
  'assholes',
  'ass',
  'bastard',
  'bastards',
  'cunt',
  'cunts',
  'dick',
  'dickhead',
  'dickheads',
  'pussy',
  'pussies',
  'slut',
  'sluts',
  'whore',
  'whores',
  'nigger',
  'niggers',
  'nigga',
  'niggas',
  'faggot',
  'faggots',
  'fag',
  'fags',
  'retard',
  'retards',
  'retarded',
  'dumbass',
  'jackass',
  'twat',
  'wanker',
  'prick',
  'pricks',
];
const PROFANITY_EN_RE = new RegExp(`\\b(?:${PROFANITY_EN_WORDS.map(spacedLetters).join('|')})\\b`, 'gi');

// Thai profanity — no `\b`, same reasoning as the Thai patterns further
// down (Thai has no spaces between words, and \b/\w are ASCII-only in JS
// regex). Deliberately excludes bare สัตว์ ("animal") and ควาย ("buffalo",
// a mild insult) — both are ordinary words with common innocent uses (pet
// products, food) — only the unambiguous insult compounds are included.
const PROFANITY_TH_RE =
  /ไอ้เหี้ย|ไอเหี้ย|อีเหี้ย|เหี้ย|ไอ้สัตว์|ไอสัตว์|อีสัตว์|สัส|ควย|เย็ด|กระหรี่|ตอแหล|ส้นตีน|อีดอก|เชี่ย|เชี้ย|แตด|หี/g;

/** Reasons that come from the profanity patterns, not the leakage ones — used to pick which warning(s) to show. */
export const PROFANITY_REASONS = new Set(['contains profanity', 'contains profanity (Thai)']);

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
    re: BRAND_RE,
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
    // "username xyz" — the generic way people share a handle for an app
    // without naming the app itself. A bare space (no "is"/":") is enough
    // here — "username" isn't used in ordinary English the way "handle" or
    // "contact" are ("I can handle this", "contact info" are common phrases;
    // "username info" isn't), so it's safe to catch without a separator.
    re: /\b(?:my\s+)?username(?:\s*(?:is|[:=-])\s*|\s+)[\w.+-]{2,}/gi,
    reason: 'mentions a possible username/ID for off-platform contact',
    placeholder: '[hidden]',
  },
  {
    // "handle"/"contact" both need an explicit separator — both are common
    // English on their own ("I can handle this", "contact info"), so a bare
    // space after them would false-positive constantly.
    re: /\b(?:my\s+)?(?:handle|contact)\s*(?:is|[:=-])\s*[\w.+-]{2,}/gi,
    reason: 'mentions a possible username/ID for off-platform contact',
    placeholder: '[hidden]',
  },
  {
    // Same idea for bare "id", kept separate because "id" alone collides with
    // the common no-apostrophe typing of "I'd" ("id like", "id love", "id
    // rather") — skip only those specific continuations so "ID johndoe123" /
    // "ID: johndoe123" / "my id is johndoe123" still all get caught.
    re: /\b(?:my\s+)?id(?:\s*(?:is|[:=-])\s*|\s+)(?!(?:like|love|want|need|rather|prefer|say|think|guess|suggest|recommend|really)\b)[\w.+-]{2,}/gi,
    reason: 'mentions a possible username/ID for off-platform contact',
    placeholder: '[hidden]',
  },
  {
    re: /\b(pay(ment)?\s*(me|directly|outside)|cash only|skip the app|off[- ]platform|outside (of )?the app)\b/gi,
    reason: 'suggests paying outside the app',
    placeholder: '[hidden]',
  },
  // Thai-script equivalents. No `\b` on any of these — Thai text has no
  // spaces between words, and `\b`/`\w` in JS regex only recognise ASCII
  // characters, so a boundary assertion would fail to match a Thai keyword
  // embedded naturally in a longer sentence with no surrounding whitespace.
  {
    // Includes short forms (อจ for IG, ฟบ/เฟส for Facebook, ตต for TikTok) —
    // same "worth the occasional false positive" trade-off as the English
    // short forms above.
    re: /ไลน์ไอดี|แอดไลน์|ไลน์|เทเลแกรม|วอทส์?แอพ|วีแชท|ไอจี|อจ|อินสตาแกรม|เฟซบุ๊ก|เฟสบุ๊ค|เฟสบุ๊ก|เฟสบุค|เฟส|ฟบ|ติ๊กต๊อก|ตั้กต๊อก|ตต|ไอดี/g,
    reason: 'mentions an outside messaging app (Thai)',
    placeholder: '[hidden]',
  },
  {
    re: /พร้อมเพย์|บัญชีธนาคาร|เลขบัญชี|เบอร์โทรศัพท์|เบอร์ติดต่อ|เบอร์โทร/g,
    reason: 'mentions bank/PromptPay/contact number details (Thai)',
    placeholder: '[hidden]',
  },
  {
    re: /จ่ายตรง|โอนเงินให้|โอนตรง|นอกแอพ/g,
    reason: 'suggests paying outside the app (Thai)',
    placeholder: '[hidden]',
  },
  {
    re: PROFANITY_EN_RE,
    reason: 'contains profanity',
    placeholder: '[language warning]',
  },
  {
    re: PROFANITY_TH_RE,
    reason: 'contains profanity (Thai)',
    placeholder: '[language warning]',
  },
];

export interface MessageRedaction {
  /** The text to actually store/show — contact info etc. replaced with a placeholder. */
  body: string;
  flagged: boolean;
  reasons: string[];
  /** True if any reason came from the profanity patterns — lets the caller show a distinct warning from the contact-leakage one. */
  profanityFlagged: boolean;
}

/**
 * Instant, free, deterministic pattern match — redacts the obvious leakage
 * attempts (contact info, off-platform payment) in place before the message
 * is ever stored, so the raw phone number / email / handle is never exposed
 * to the other party even briefly. Runs synchronously on every send; the
 * subtler cases (harassment, indirect phrasing) are left to the async AI
 * pass below, which can't redact — see `runChatModerationCheck`.
 */
// Reasons that mean "this message is trying to move the conversation off
// the platform" — once one of these fires, a nearby number is unambiguous
// regardless of length, unlike a bare number found on its own.
const CONTEXTUAL_TRIGGER_REASONS = new Set([
  'mentions bank/PromptPay payment details',
  'mentions an outside messaging app',
  'suggests paying outside the app',
  'mentions an outside messaging app (Thai)',
  'mentions bank/PromptPay/contact number details (Thai)',
  'suggests paying outside the app (Thai)',
]);

/** 4+ digits, not 9+ — only ever applied after a payment/app keyword already fired. */
const SHORT_NUMBER_RE = /\b\d(?:[-.\s]?\d){3,}\b/g;

export function redactLeakage(body: string): MessageRedaction {
  const reasons = new Set<string>();
  let redacted = body;
  for (const { re, reason, placeholder } of LEAK_PATTERNS) {
    if (re.test(redacted)) reasons.add(reason);
    redacted = redacted.replace(re, placeholder);
  }

  // "my promptpay is 98268203" — 8 digits, under the general 9-digit
  // threshold that keeps ordinary numbers (prices, quantities) from being
  // flagged. But the keyword already makes intent unambiguous, so sweep
  // again for shorter digit runs once one has fired.
  if ([...reasons].some((r) => CONTEXTUAL_TRIGGER_REASONS.has(r))) {
    if (SHORT_NUMBER_RE.test(redacted)) reasons.add('possible phone/account number');
    redacted = redacted.replace(SHORT_NUMBER_RE, '[number hidden]');
  }

  return {
    body: redacted,
    flagged: reasons.size > 0,
    reasons: [...reasons],
    profanityFlagged: [...reasons].some((r) => PROFANITY_REASONS.has(r)),
  };
}

export const leakageWarning = (locale: SupportedLocale): string => t(locale, 'messages.leakageWarning');
export const qrWarning = (locale: SupportedLocale): string => t(locale, 'messages.qrWarning');
export const profanityWarning = (locale: SupportedLocale): string => t(locale, 'messages.profanityWarning');

/** What a participant should see instead of the raw body, if anything. */
export function presentMessageBody(
  message: { body: string; hidden_at?: Date | string | null; sender_id: string },
  viewerId: string,
  locale: SupportedLocale
): string {
  if (!message.hidden_at) return message.body;
  return t(locale, message.sender_id === viewerId ? 'messages.hiddenToSender' : 'messages.hiddenToOthers');
}

interface MessageForCheck {
  id: string;
  order_id: string;
  sender_id: string;
  body: string;
  /** Already past the QR check — never a photo that was rejected outright. */
  image_url?: string | null;
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
    // Signed for the same reason as the receipt check (see
    // src/services/receipt-check.ts) — the real analyzer fetches this URL
    // itself, and it now needs a valid signature like anyone else would.
    const result = await getChatModerationAnalyzer().analyze({
      body: message.body,
      imageUrl: signPrivateUploadUrl(message.image_url),
    });
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

    // The instant regex/QR checks return a `warning` in the send response
    // itself, so the sender finds out immediately. This check runs after
    // that response has already gone out, so a hidden message needs its own
    // notification or the sender only discovers it by noticing the
    // placeholder text next time they open the chat.
    if (result.risk === 'high') {
      await recordNotification(db, {
        userId: message.sender_id,
        type: 'message_flagged',
        params: {},
        orderId: message.order_id,
        link: `/orders/${message.order_id}/chat`,
      });
    }
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[chat-moderation] failed for message', message.id, err);
    // console.warn alone only reaches Render's raw logs, which an operator
    // without dashboard access can't easily check — mirror it to the audit
    // trail (visible in the admin console's Audit tab) so a persistently
    // failing check (bad API key, no credits, model access issue) is
    // actually discoverable, not just silently degrading to no moderation.
    await recordAudit(
      db,
      { id: null, role: 'system' },
      {
        action: 'message.check_failed',
        targetType: 'message',
        targetId: message.id,
        summary: `AI chat check failed for a message on order ${message.order_id}: ${
          err instanceof Error ? err.message : String(err)
        }`,
        metadata: { error: err instanceof Error ? err.message : String(err) },
      }
    );
  }
}
