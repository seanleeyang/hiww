/**
 * "Hard" push notifications — delivered by the OS even with the app fully
 * closed, unlike the in-app notification feed (`src/services/notify.ts`),
 * which only shows up the next time the app polls. Kept behind this
 * interface the same way the AI/payment/identity providers are, so tests
 * and local dev run a deterministic mock and only production talks to a
 * real provider.
 */

export interface PushMessage {
  title: string;
  body: string;
  /** Extra payload the client uses to act on a tap — e.g. `{ link: '/orders/xyz' }`. */
  data?: Record<string, string>;
}

export interface PushSendResult {
  /** Tokens the provider reported as dead/unregistered — the caller should
   * delete these rows so they don't accumulate forever. */
  deadTokens: string[];
}

export interface PushSender {
  /**
   * Sends the same message to every given token. Best-effort per token — a
   * batch with some invalid tokens should still deliver to the valid ones
   * and report which are dead, not throw.
   */
  send(tokens: string[], message: PushMessage): Promise<PushSendResult>;
}
