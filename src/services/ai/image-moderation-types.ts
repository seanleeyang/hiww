/**
 * AI content screening for a general photo upload (want photos, trip
 * covers, avatars — anything that goes through `POST /api/uploads` and is
 * shown publicly with no other review). Kept behind this interface the same
 * way the other analyzers are — tests and local dev run a deterministic
 * mock, only production talks to a real model.
 */

export type ImageModerationRisk = 'low' | 'medium' | 'high';

export interface ImageModerationInput {
  /** Raw bytes already in memory from the upload — no extra fetch needed. */
  data: Buffer;
  mimeType: 'image/jpeg' | 'image/png' | 'image/webp';
  /**
   * The client-supplied filename. Only the mock analyzer looks at this (as a
   * test seam, the same way the chat-moderation mock keys off message text)
   * — the real analyzer judges the image content itself, never the name.
   */
  filename?: string;
}

export interface ImageModerationResult {
  risk: ImageModerationRisk;
  /** Specific concerns, empty when nothing stood out. */
  reasons: string[];
  /** One sentence an operator can read at a glance. */
  summary: string;
  /** Model id that produced this, or `mock`. */
  model: string;
  analyzedAt: string;
}

export interface ImageModerationAnalyzer {
  analyze(input: ImageModerationInput): Promise<ImageModerationResult>;
}
