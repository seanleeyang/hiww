import type {
  ChatModerationAnalyzer,
  ChatModerationInput,
  ChatModerationResult,
} from './chat-moderation-types';

/**
 * Deterministic stand-in for the real model. The risk it returns is driven by
 * the message body so tests and the operator console can exercise both paths:
 *
 *   …contains "suspicious"…  → high
 *   …contains "flagme"…      → medium
 *   anything else            → low
 */
export class MockChatModerationAnalyzer implements ChatModerationAnalyzer {
  async analyze(input: ChatModerationInput): Promise<ChatModerationResult> {
    const body = input.body.toLowerCase();
    const risk = body.includes('suspicious') ? 'high' : body.includes('flagme') ? 'medium' : 'low';

    const reasons =
      risk === 'high'
        ? ['Message reads as abusive or threatening']
        : risk === 'medium'
          ? ['Message may be trying to move the deal off-platform']
          : [];

    return {
      risk,
      reasons,
      summary:
        risk === 'low'
          ? 'Message looks fine.'
          : `Mock analyzer flagged this message as ${risk} risk.`,
      model: 'mock',
      analyzedAt: new Date().toISOString(),
    };
  }
}
