import type {
  ItemPhotoAssessment,
  ReceiptAnalyzer,
  ReceiptAnalysisInput,
  ReceiptAnalysis,
  ReceiptRisk,
} from './types';

/**
 * Deterministic stand-in for the real model. The risk it returns is driven by
 * the image URL(s) so tests and the operator console can exercise every path:
 *
 *   receipt URL contains …/suspicious…    → high risk
 *   receipt URL contains …/flagme…        → medium risk
 *   item photo URL contains …/mismatch…   → itemPhotoAssessment: "mismatch"
 *   anything else                         → low risk, "match" (or "not_provided")
 */
export class MockReceiptAnalyzer implements ReceiptAnalyzer {
  async analyze(input: ReceiptAnalysisInput): Promise<ReceiptAnalysis> {
    const url = input.imageUrl.toLowerCase();
    let risk: ReceiptRisk = url.includes('suspicious')
      ? 'high'
      : url.includes('flagme')
        ? 'medium'
        : 'low';

    const itemPhotoAssessment: ItemPhotoAssessment = !input.itemPhotoUrl
      ? 'not_provided'
      : input.itemPhotoUrl.toLowerCase().includes('mismatch')
        ? 'mismatch'
        : 'match';

    // A mismatched item photo is itself a red flag, same as the real model
    // is instructed to treat it — never let it silently stay "low".
    if (itemPhotoAssessment === 'mismatch' && risk === 'low') {
      risk = 'medium';
    }

    const flags = [
      ...(risk === 'high'
        ? ['Image looks edited', 'Total does not match the order amount']
        : risk === 'medium'
          ? ['Receipt date is hard to read']
          : []),
      ...(itemPhotoAssessment === 'mismatch' ? ['Item photo does not appear to match the request'] : []),
    ];

    return {
      risk,
      summary:
        risk === 'low'
          ? 'Receipt looks consistent with the order.'
          : `Mock analyzer flagged this receipt as ${risk} risk.`,
      flags,
      extracted: {
        merchant: 'Mock Store',
        merchantOriginal: 'モックストア',
        date: input.orderCreatedAt.toISOString().slice(0, 10),
        currency: 'THB',
        total: input.expectedAmount,
        items: [input.itemDescription],
        language: 'English',
      },
      itemPhotoAssessment,
      model: 'mock',
      analyzedAt: new Date().toISOString(),
    };
  }
}
