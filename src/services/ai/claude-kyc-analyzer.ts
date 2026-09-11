import Anthropic from '@anthropic-ai/sdk';
import type { FieldMatch, KycAnalysis, KycAnalysisInput, KycAnalyzer, KycRisk } from './kyc-types';
import { fetchImage } from './fetch-image';

const SYSTEM = `You review identity-check submissions for a cross-border shopping marketplace pilot.
A user has photographed their ID document (passport, national ID card, or driver's license) and a
selfie of themselves holding that same document, and typed in the name/ID number/address they claim
the document shows. Your job is to help a human operator spot problems — you never make the final
call, and nothing you say alone approves or rejects anyone.

Documents come from many countries and can be printed in any script. Read and interpret the document
regardless of language, but write "extracted" values in the same script/language they're printed in
(do not translate a name or address — transcribe it as printed).

Return ONLY a JSON object, no prose, with exactly these keys:
{
  "risk": "low" | "medium" | "high",
  "summary": string,             // one or two sentences for the operator, in English
  "flags": string[],             // specific concerns; [] if nothing stands out
  "extracted": {
    "firstName": string | null,  // as printed on the document
    "lastName": string | null,
    "documentId": string | null,
    "address": string | null     // null if the document has no address field (e.g. most passports)
  },
  "nameMatch": "match" | "mismatch" | "unclear",
  "documentIdMatch": "match" | "mismatch" | "unclear",
  "addressMatch": "match" | "mismatch" | "unclear",
  "faceMatch": "match" | "mismatch" | "unclear",
  "documentAuthenticity": "plausible" | "suspicious"
}

nameMatch/documentIdMatch/addressMatch compare what you extracted against what the user typed in (given
below) — small transliteration or spacing differences are still "match"; a clearly different name or
number is "mismatch"; use "unclear" only if the document is genuinely illegible there. If the document
has no address field at all (most passports), set addressMatch to "unclear" rather than penalising it.

faceMatch compares the face in the selfie photo against the face in the document's photo — "mismatch"
only for a clearly different person, "unclear" if the selfie doesn't show a face clearly, or doesn't
show the document at all.

documentAuthenticity is "suspicious" when the document image looks edited, is a screenshot of a screen,
has a photo that looks pasted on, has mismatched fonts, or otherwise doesn't look like a genuine photo
of a physical document. Being a low-quality phone photo is NOT itself a reason for "suspicious".

Set "risk": "high" for any clear mismatch (name, ID number, or face) or a suspicious document; "medium"
for a single soft/unclear concern; "low" when everything is consistent.`;

export class ClaudeKycAnalyzer implements KycAnalyzer {
  private readonly client: Anthropic;

  constructor(
    apiKey: string,
    private readonly model: string
  ) {
    this.client = new Anthropic({ apiKey });
  }

  async analyze(input: KycAnalysisInput): Promise<KycAnalysis> {
    const document = await fetchImage(input.documentPhotoUrl);
    const documentBack = input.documentPhotoBackUrl ? await fetchImage(input.documentPhotoBackUrl) : null;
    const selfie = await fetchImage(input.selfiePhotoUrl);

    const userText = [
      `Document type: ${input.documentType}`,
      `Submitted first name: ${input.submittedFirstName}`,
      `Submitted last name: ${input.submittedLastName}`,
      `Submitted document number: ${input.submittedDocumentId}`,
      `Submitted address: ${input.submittedAddress}`,
      documentBack
        ? 'The first image is the front of the document, the second is a second page of it (e.g. a visa stamp page, or the back of a card), and the third is the selfie holding the document. Analyse all three.'
        : 'The first image is the document, the second is the selfie holding it. Analyse both.',
    ].join('\n');

    const images = [document, ...(documentBack ? [documentBack] : []), selfie];

    const response = await this.client.beta.messages.create({
      model: this.model,
      max_tokens: 2000,
      betas: ['server-side-fallback-2026-06-01'],
      fallbacks: [{ model: 'claude-opus-4-8' }],
      output_config: { effort: 'medium' },
      system: SYSTEM,
      messages: [
        {
          role: 'user',
          content: [
            ...images.map((img) => ({
              type: 'image' as const,
              source: { type: 'base64' as const, media_type: img.mediaType, data: img.data },
            })),
            { type: 'text', text: userText },
          ],
        },
      ],
    });

    if (response.stop_reason === 'refusal') {
      return neutral(this.model, 'The model declined to analyse this submission.');
    }

    const text = response.content
      .filter((b): b is Anthropic.Beta.BetaTextBlock => b.type === 'text')
      .map((b) => b.text)
      .join('')
      .trim();

    return parseAnalysis(text, this.model);
  }
}

function parseAnalysis(text: string, model: string): KycAnalysis {
  // The model is asked for bare JSON, but tolerate a ```json fence just in case.
  const jsonSlice = text.replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
  let raw: unknown;
  try {
    raw = JSON.parse(jsonSlice);
  } catch {
    return neutral(model, 'The analysis response could not be parsed.');
  }

  const obj = raw as Record<string, unknown>;
  const risk: KycRisk = obj.risk === 'high' || obj.risk === 'medium' || obj.risk === 'low' ? obj.risk : 'low';
  const ex = (obj.extracted ?? {}) as Record<string, unknown>;
  const match = (v: unknown): FieldMatch => (v === 'match' || v === 'mismatch' ? v : 'unclear');

  return {
    risk,
    summary: typeof obj.summary === 'string' ? obj.summary : '',
    flags: Array.isArray(obj.flags) ? obj.flags.filter((f): f is string => typeof f === 'string') : [],
    extracted: {
      firstName: str(ex.firstName),
      lastName: str(ex.lastName),
      documentId: str(ex.documentId),
      address: str(ex.address),
    },
    nameMatch: match(obj.nameMatch),
    documentIdMatch: match(obj.documentIdMatch),
    addressMatch: match(obj.addressMatch),
    faceMatch: match(obj.faceMatch),
    documentAuthenticity: obj.documentAuthenticity === 'suspicious' ? 'suspicious' : 'plausible',
    model,
    analyzedAt: new Date().toISOString(),
  };
}

function neutral(model: string, summary: string): KycAnalysis {
  return {
    risk: 'low',
    summary,
    flags: [],
    extracted: { firstName: null, lastName: null, documentId: null, address: null },
    nameMatch: 'unclear',
    documentIdMatch: 'unclear',
    addressMatch: 'unclear',
    faceMatch: 'unclear',
    documentAuthenticity: 'plausible',
    model,
    analyzedAt: new Date().toISOString(),
  };
}

function str(v: unknown): string | null {
  return typeof v === 'string' && v.trim() !== '' ? v.trim() : null;
}
