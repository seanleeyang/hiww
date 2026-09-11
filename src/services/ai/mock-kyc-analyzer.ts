import type { FieldMatch, KycAnalysis, KycAnalysisInput, KycAnalyzer, KycRisk } from './kyc-types';

/**
 * Deterministic stand-in for the real model. Driven by the photo URLs so
 * tests and the admin console can exercise every path:
 *
 *   document URL contains …/suspicious…  → high risk, document not authentic
 *   document URL contains …/mismatch…    → the extracted name/ID/address don't match what was submitted
 *   selfie URL contains …/faceMismatch…  → faceMatch: "mismatch"
 *   anything else                        → low risk, everything matches
 */
export class MockKycAnalyzer implements KycAnalyzer {
  async analyze(input: KycAnalysisInput): Promise<KycAnalysis> {
    const docUrl = input.documentPhotoUrl.toLowerCase();
    const selfieUrl = input.selfiePhotoUrl.toLowerCase();

    const suspicious = docUrl.includes('suspicious');
    const fieldsMismatch = docUrl.includes('mismatch');
    const faceMismatch = selfieUrl.includes('facemismatch');

    const fieldMatch: FieldMatch = fieldsMismatch ? 'mismatch' : 'match';
    const faceMatchResult: FieldMatch = faceMismatch ? 'mismatch' : 'match';

    let risk: KycRisk = 'low';
    if (suspicious || faceMismatch) risk = 'high';
    else if (fieldsMismatch) risk = 'medium';

    const flags = [
      ...(suspicious ? ['Document looks edited or not genuine'] : []),
      ...(fieldsMismatch ? ['Submitted details do not match the document'] : []),
      ...(faceMismatch ? ['Selfie does not appear to match the document photo'] : []),
    ];

    return {
      risk,
      summary: risk === 'low' ? 'Submission is consistent — no concerns.' : `Mock analyzer flagged this as ${risk} risk.`,
      flags,
      extracted: {
        firstName: fieldsMismatch ? 'Different' : input.submittedFirstName,
        lastName: fieldsMismatch ? 'Person' : input.submittedLastName,
        documentId: fieldsMismatch ? 'X0000000' : input.submittedDocumentId,
        address: fieldsMismatch ? '123 Somewhere Else St' : input.submittedAddress,
      },
      nameMatch: fieldMatch,
      documentIdMatch: fieldMatch,
      addressMatch: fieldMatch,
      faceMatch: faceMatchResult,
      documentAuthenticity: suspicious ? 'suspicious' : 'plausible',
      model: 'mock',
      analyzedAt: new Date().toISOString(),
    };
  }
}
