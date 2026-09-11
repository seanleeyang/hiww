import { config } from '@/config/env';
import type { ReceiptAnalyzer } from './types';
import { MockReceiptAnalyzer } from './mock-receipt-analyzer';
import { ClaudeReceiptAnalyzer } from './claude-receipt-analyzer';
import type { ChatModerationAnalyzer } from './chat-moderation-types';
import { MockChatModerationAnalyzer } from './mock-chat-moderation-analyzer';
import { ClaudeChatModerationAnalyzer } from './claude-chat-moderation-analyzer';
import type { KycAnalyzer } from './kyc-types';
import { MockKycAnalyzer } from './mock-kyc-analyzer';
import { ClaudeKycAnalyzer } from './claude-kyc-analyzer';

export type { ReceiptAnalyzer, ReceiptAnalysis, ReceiptRisk, ReceiptAnalysisInput } from './types';
export type {
  ChatModerationAnalyzer,
  ChatModerationResult,
  ModerationRisk,
  ChatModerationInput,
} from './chat-moderation-types';
export type { KycAnalyzer, KycAnalysis, KycRisk, KycAnalysisInput, FieldMatch } from './kyc-types';

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

let cachedModeration: ChatModerationAnalyzer | undefined;

/**
 * The configured chat moderation analyzer. `claude` needs both
 * AI_CHAT_MODERATION=claude and an ANTHROPIC_API_KEY; anything else (and the
 * test run) gets the mock.
 */
export function getChatModerationAnalyzer(): ChatModerationAnalyzer {
  if (cachedModeration) return cachedModeration;
  cachedModeration =
    config.aiChatModeration === 'claude' && config.anthropicApiKey
      ? new ClaudeChatModerationAnalyzer(config.anthropicApiKey, config.aiChatModel)
      : new MockChatModerationAnalyzer();
  return cachedModeration;
}

/** Test seam. */
export function __setChatModerationAnalyzer(analyzer: ChatModerationAnalyzer | undefined): void {
  cachedModeration = analyzer;
}

let cachedKyc: KycAnalyzer | undefined;

/**
 * The configured KYC analyzer. `claude` needs both AI_KYC_CHECK=claude and
 * an ANTHROPIC_API_KEY; anything else (and the test run) gets the mock.
 */
export function getKycAnalyzer(): KycAnalyzer {
  if (cachedKyc) return cachedKyc;
  cachedKyc =
    config.aiKycCheck === 'claude' && config.anthropicApiKey
      ? new ClaudeKycAnalyzer(config.anthropicApiKey, config.aiKycModel)
      : new MockKycAnalyzer();
  return cachedKyc;
}

/** Test seam. */
export function __setKycAnalyzer(analyzer: KycAnalyzer | undefined): void {
  cachedKyc = analyzer;
}
