import type {
  ImageModerationAnalyzer,
  ImageModerationInput,
  ImageModerationResult,
} from './image-moderation-types';

/**
 * Deterministic stand-in for the real model. The risk it returns is driven
 * by the uploaded filename (never the actual bytes — this is a test seam)
 * so tests can exercise both paths without needing a real explicit image:
 *
 *   filename contains "explicit-test"  → high
 *   filename contains "flagme-test"    → medium
 *   anything else                      → low
 */
export class MockImageModerationAnalyzer implements ImageModerationAnalyzer {
  async analyze(input: ImageModerationInput): Promise<ImageModerationResult> {
    const name = (input.filename ?? '').toLowerCase();
    const risk = name.includes('explicit-test')
      ? 'high'
      : name.includes('flagme-test')
        ? 'medium'
        : 'low';

    const reasons =
      risk === 'high'
        ? ['Image appears to contain explicit or graphic content']
        : risk === 'medium'
          ? ['Image content is ambiguous and may warrant a look']
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
