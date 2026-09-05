import { config } from '@/config/env';
import type { ReceiptAnalyzer } from './types';
import { MockReceiptAnalyzer } from './mock-receipt-analyzer';
import { ClaudeReceiptAnalyzer } from './claude-receipt-analyzer';

export type { ReceiptAnalyzer, ReceiptAnalysis, ReceiptRisk, ReceiptAnalysisInput } from './types';

let cached: ReceiptAnalyzer | undefined;

/**
 * The configured receipt analyzer. `claude` needs both AI_RECEIPT_ANALYZER=claude
 * and an ANTHROPIC_API_KEY; anything else (and the test run) gets the mock.
 */
export function getReceiptAnalyzer(): ReceiptAnalyzer {
  if (cached) return cached;
  cached =
    config.aiReceiptAnalyzer === 'claude' && config.anthropicApiKey
      ? new ClaudeReceiptAnalyzer(config.anthropicApiKey, config.aiModel)
      : new MockReceiptAnalyzer();
  return cached;
}

/** Test seam. */
export function __setReceiptAnalyzer(analyzer: ReceiptAnalyzer | undefined): void {
  cached = analyzer;
}
