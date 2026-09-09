/**
 * AI receipt check. Kept behind this interface the same way payment/identity
 * providers are — so tests and local dev run a deterministic mock and only
 * production talks to a real model.
 */

export type ReceiptRisk = 'low' | 'medium' | 'high';

export type ItemPhotoAssessment = 'match' | 'mismatch' | 'unclear' | 'not_provided';

export interface ReceiptAnalysisInput {
  /** Public URL of the uploaded receipt photo. */
  imageUrl: string;
  /** Public URL of a photo of the item itself, if the traveler attached one. */
  itemPhotoUrl?: string | null;
  /** What the shopper asked to be bought. */
  itemDescription: string;
  /** The want's category (e.g. "sneakers", "beauty"), for the item-photo check. */
  category?: string | null;
  /** The order total the shopper paid (decimal string, THB). */
  expectedAmount: string;
  /** Country the item was to be bought in, if known. */
  sourceCountry?: string | null;
  /** When the order was created — a receipt should not predate it. */
  orderCreatedAt: Date;
}

export interface ReceiptExtracted {
  /** Merchant name translated into English for the operator. */
  merchant: string | null;
  /** Merchant name exactly as printed, in its original script. */
  merchantOriginal: string | null;
  date: string | null;
  currency: string | null;
  total: string | null;
  /** Line items translated into English. */
  items: string[];
  /** Detected language/script of the receipt, e.g. "Japanese", "Chinese (Simplified)", "Thai". */
  language: string | null;
}

export interface ReceiptAnalysis {
  risk: ReceiptRisk;
  /** One or two sentences an operator can read at a glance. */
  summary: string;
  /** Specific concerns, empty when nothing stood out. */
  flags: string[];
  extracted: ReceiptExtracted;
  /** Whether the item photo (if any) plausibly shows the requested item. */
  itemPhotoAssessment: ItemPhotoAssessment;
  /** Model id that produced this, or `mock`. */
  model: string;
  analyzedAt: string;
}

export interface ReceiptAnalyzer {
  analyze(input: ReceiptAnalysisInput): Promise<ReceiptAnalysis>;
}
