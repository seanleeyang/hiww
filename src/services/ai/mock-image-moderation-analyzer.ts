import type {
  ImageModerationAnalyzer,
  ImageModerationInput,
  ImageModerationResult,
} from './image-moderation-types';

/**
 * Deterministic stand-in for the real model. The risk it returns is driven
 * by the uploaded filename (never the actual bytes — this is a test seam)
 * so tests can exercise every path without needing a real explicit image:
 *
 *   filename contains "explicit-test"        → high  (explicit/graphic content)
 *   filename contains "flagme-test"          → medium (generic ambiguous content)
 *   filename contains "royal-disrespect-test" → high  (mocking/disrespectful royal content)
 *   filename contains "royal-test"           → medium (royal content, nothing disrespectful)
 *   anything else                            → low
 */
export class MockImageModerationAnalyzer implements ImageModerationAnalyzer {
  async analyze(input: ImageModerationInput): Promise<ImageModerationResult> {
    const name = (input.filename ?? '').toLowerCase();
    const risk = name.includes('explicit-test') || name.includes('royal-disrespect-test')
      ? 'high'
      : name.includes('flagme-test') || name.includes('royal-test')
        ? 'medium'
        : 'low';

    const reasons =
      risk === 'high'
        ? name.includes('royal-disrespect-test')
          ? ['Image appears to mock or disrespect the Thai monarchy']
          : ['Image appears to contain explicit or graphic content']
        : risk === 'medium'
          ? name.includes('royal-test')
            ? ['Thai royal imagery is the main subject — needs a human legal-context look']
            : ['Image content is ambiguous and may warrant a look']
          : [];

    return {
      risk,
      reasons,
      summary:
        risk === 'low' ? 'Image looks fine.' : `Mock analyzer flagged this image as ${risk} risk.`,
      model: 'mock',
      analyzedAt: new Date().toISOString(),
    };
  }
}
