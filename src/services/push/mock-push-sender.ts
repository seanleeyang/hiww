import type { PushSender, PushMessage, PushSendResult } from './types';

export interface SentPush {
  tokens: string[];
  message: PushMessage;
}

/**
 * Deterministic stand-in for a real push provider. Records what would have
 * been sent (inspect `.sent` in tests) instead of calling out to Firebase,
 * and reports any token containing "dead" as one the provider would have
 * pruned, so the token-cleanup path can be exercised too:
 *
 *   token contains "dead"  -> reported back as a dead token
 *   anything else          -> delivered, kept
 */
export class MockPushSender implements PushSender {
  readonly sent: SentPush[] = [];

  async send(tokens: string[], message: PushMessage): Promise<PushSendResult> {
    this.sent.push({ tokens, message });
    // eslint-disable-next-line no-console
    console.log('[push:mock]', tokens.length, 'device(s) —', message.title, '-', message.body);
    return { deadTokens: tokens.filter((t) => t.toLowerCase().includes('dead')) };
  }
}
