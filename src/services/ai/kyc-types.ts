/**
 * AI KYC check. Same shape as the receipt analyzer — kept behind an
 * interface so tests and local dev run a deterministic mock and only
 * production talks to a real model. Advisory only: it never sets
 * `kyc_status` itself, it just gives the human reviewer a head start.
 */

export type KycRisk = 'low' | 'medium' | 'high';

export type FieldMatch = 'match' | 'mismatch' | 'unclear';

export interface KycAnalysisInput {
  documentType: 'passport' | 'id_card' | 'drivers_license';
  /** Public URL of the front of the document. */
  documentPhotoUrl: string;
  /** Public URL of a second page, if attached (visa stamp page, back of a card). */
  documentPhotoBackUrl?: string | null;
  /** Public URL of the user holding the document, for a face-match check. */
  selfiePhotoUrl: string;
  submittedFirstName: string;
  submittedLastName: string;
  submittedDocumentId: string;
  submittedAddress: string;
}

export interface KycExtracted {
  firstName: string | null;
  lastName: string | null;
  documentId: string | null;
  address: string | null;
}

export interface KycAnalysis {
  risk: KycRisk;
  /** One or two sentences an operator can read at a glance. */
  summary: string;
  /** Specific concerns, empty when nothing stood out. */
  flags: string[];
  extracted: KycExtracted;
  nameMatch: FieldMatch;
  documentIdMatch: FieldMatch;
  addressMatch: FieldMatch;
  /** Whether the selfie plausibly shows the same person as the document photo. */
  faceMatch: FieldMatch;
  /** Whether the document itself looks genuine (no obvious tampering/screenshotting). */
  documentAuthenticity: 'plausible' | 'suspicious';
  /** Model id that produced this, or `mock`. */
  model: string;
  analyzedAt: string;
}

export interface KycAnalyzer {
  analyze(input: KycAnalysisInput): Promise<KycAnalysis>;
}
