/**
 * AI chat moderation. Kept behind this interface the same way the receipt
 * analyzer is — tests and local dev run a deterministic mock, only
 * production talks to a real model.
 */

export type ModerationRisk = 'low' | 'medium' | 'high';

export interface ChatModerationInput {
  /** The message text being checked. */
  body: string;
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
