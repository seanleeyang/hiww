/**
 * AI receipt check. Kept behind this interface the same way payment/identity
 * providers are — so tests and local dev run a deterministic mock and only
 * production talks to a real model.
 */

export type ReceiptRisk = 'low' | 'medium' | 'high';

export interface ReceiptAnalysisInput {
  /** Public URL of the uploaded receipt photo. */
  imageUrl: string;
  /** What the shopper asked to be bought. */
  itemDescription: string;
  /** The order total the shopper paid (decimal string). */
  expectedAmount: string;
  /** Country the item was to be bought in, if known. */
  sourceCountry?: string | null;
  /** When the order was created — a receipt should not predate it. */
  orderCreatedAt: Date;
}

export interface ReceiptExtracted {
  merchant: string | null;
  date: string | null;
  currency: string | null;
  total: string | null;
  items: string[];
}

export interface ReceiptAnalysis {
  risk: ReceiptRisk;
  /** One or two sentences an operator can read at a glance. */
  summary: string;
  /** Specific concerns, empty when nothing stood out. */
  flags: string[];
  extracted: ReceiptExtracted;
  /** Model id that produced this, or `mock`. */
  model: string;
  analyzedAt: string;
}

export interface ReceiptAnalyzer {
  analyze(input: ReceiptAnalysisInput): Promise<ReceiptAnalysis>;
}
