/**
 * AI chat moderation. Kept behind this interface the same way the receipt
 * analyzer is — tests and local dev run a deterministic mock, only
 * production talks to a real model.
 */

export type ModerationRisk = 'low' | 'medium' | 'high';

export interface ChatModerationInput {
  /** The message text being checked. */
  body: string;
  /**
   * Public URL of an attached photo, if any (already past the QR check —
   * this is only ever a photo that wasn't rejected outright). Checked for
   * contact/payment info written or displayed in it — a handwritten note, a
   * screenshot, a business card — that the QR-code check can't catch since
   * it's not a QR code.
   */
  imageUrl?: string | null;
}

export interface ChatModerationResult {
  risk: ModerationRisk;
  /** Specific concerns, empty when nothing stood out. */
  reasons: string[];
  /** One sentence an operator can read at a glance. */
  summary: string;
  /** Model id that produced this, or `mock`. */
  model: string;
  analyzedAt: string;
}

export interface ChatModerationAnalyzer {
  analyze(input: ChatModerationInput): Promise<ChatModerationResult>;
}
