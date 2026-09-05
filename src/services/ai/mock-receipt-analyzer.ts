import type { ReceiptAnalyzer, ReceiptAnalysisInput, ReceiptAnalysis } from './types';

/**
 * Deterministic stand-in for the real model. The risk it returns is driven by
 * the image URL so tests and the operator console can exercise both paths:
 *
 *   …/suspicious…  → high
 *   …/flagme…      → medium
 *   anything else  → low
 */
export class MockReceiptAnalyzer implements ReceiptAnalyzer {
  async analyze(input: ReceiptAnalysisInput): Promise<ReceiptAnalysis> {
    const url = input.imageUrl.toLowerCase();
    const risk = url.includes('suspicious')
      ? 'high'
      : url.includes('flagme')
        ? 'medium'
        : 'low';

    const flags =
      risk === 'high'
        ? ['Image looks edited', 'Total does not match the order amount']
        : risk === 'medium'
          ? ['Receipt date is hard to read']
          : [];

    return {
      risk,
      summary:
        risk === 'low'
          ? 'Receipt looks consistent with the order.'
          : `Mock analyzer flagged this receipt as ${risk} risk.`,
      flags,
      extracted: {
        merchant: 'Mock Store',
        date: input.orderCreatedAt.toISOString().slice(0, 10),
        currency: 'THB',
        total: input.expectedAmount,
        items: [input.itemDescription],
      },
      model: 'mock',
      analyzedAt: new Date().toISOString(),
    };
  }
}
