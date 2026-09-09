import Anthropic from '@anthropic-ai/sdk';
import type {
  ReceiptAnalyzer,
  ReceiptAnalysisInput,
  ReceiptAnalysis,
  ReceiptRisk,
  ItemPhotoAssessment,
} from './types';
import { fetchImage } from './fetch-image';

const SYSTEM = `You review purchase evidence for a cross-border shopping marketplace.
A traveller has bought an item for a shopper and uploaded a photo of the shop receipt
as proof of purchase — usually alongside a photo of the item itself. Your job is to
help a human operator spot problems — you never make the final call.

Receipts come from many countries and can be printed in any script, including Chinese
(Simplified or Traditional), Japanese, Korean, Thai, or English. Read and interpret the
receipt regardless of language: translate the merchant name and line items into English
for "merchant" and "items", but also copy the merchant name exactly as printed, in its
original script, into "merchantOriginal", and name the detected language in "language"
(e.g. "Japanese", "Chinese (Simplified)", "Chinese (Traditional)", "Korean", "Thai",
"English"). Never refuse or degrade the analysis just because the text isn't in English.

Return ONLY a JSON object, no prose, with exactly these keys:
{
  "risk": "low" | "medium" | "high",
  "summary": string,            // one or two sentences for the operator, in English
  "flags": string[],            // specific concerns; [] if nothing stands out
  "extracted": {
    "merchant": string | null,        // translated into English
    "merchantOriginal": string | null,// exactly as printed, original script
    "date": string | null,            // as printed on the receipt
    "currency": string | null,        // e.g. "JPY", "KRW", "CNY", "THB"
    "total": string | null,           // numeric string, as printed
    "items": string[],                // translated into English
    "language": string | null         // detected receipt language/script
  },
  "itemPhotoAssessment": "match" | "mismatch" | "unclear" | "not_provided"
}

Raise the risk when: the receipt image looks edited, screenshotted, or is not a photo
of a paper or digital receipt; the printed date is before the order was placed or
implausibly old; the items on the receipt do not match what was requested; the receipt
is unreadable or clearly not a purchase receipt; an item photo was attached but doesn't
plausibly show the requested item or category, or looks like a stock/downloaded image
rather than something the traveller actually photographed. "low" means nothing notable,
"medium" means one soft concern, "high" means a clear red flag.

The receipt total is in the buy-in country's local currency, not the amount the shopper
paid in Thai baht — never flag a mismatch just because the raw numbers differ. Only flag
the total if it looks implausible for the requested item even allowing for currency
conversion (e.g. off by an order of magnitude, or clearly for a different kind of item).

Set "itemPhotoAssessment" to "not_provided" when no item photo was attached, "match" when
it plausibly shows the requested item, "mismatch" when it clearly doesn't, and "unclear"
when you can't tell either way.`;

export class ClaudeReceiptAnalyzer implements ReceiptAnalyzer {
  private readonly client: Anthropic;

  constructor(
    apiKey: string,
    private readonly model: string
  ) {
    this.client = new Anthropic({ apiKey });
  }

  async analyze(input: ReceiptAnalysisInput): Promise<ReceiptAnalysis> {
    const receipt = await fetchImage(input.imageUrl);
    const itemPhoto = input.itemPhotoUrl ? await fetchImage(input.itemPhotoUrl) : null;

    const userText = [
      `Item requested: ${input.itemDescription}`,
      input.category ? `Category: ${input.category}` : null,
      `Amount the shopper paid (order total, THB): ${input.expectedAmount}`,
      `Buy-in country: ${input.sourceCountry ?? 'unknown'}`,
      `Order placed: ${input.orderCreatedAt.toISOString()}`,
      itemPhoto
        ? 'The first image is the shop receipt; the second image is a photo of the item the traveller bought. Analyse both.'
        : 'Analyse the attached receipt. No item photo was provided — set itemPhotoAssessment to "not_provided".',
    ].filter((line): line is string => line !== null).join('\n');

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
            { type: 'image', source: { type: 'base64', media_type: receipt.mediaType, data: receipt.data } },
            ...(itemPhoto
              ? [
                  {
                    type: 'image' as const,
                    source: {
                      type: 'base64' as const,
                      media_type: itemPhoto.mediaType,
                      data: itemPhoto.data,
                    },
                  },
                ]
              : []),
            { type: 'text', text: userText },
          ],
        },
      ],
    });

    if (response.stop_reason === 'refusal') {
      return neutral(this.model, 'The model declined to analyse this image.', !!itemPhoto);
    }

    const text = response.content
      .filter((b): b is Anthropic.Beta.BetaTextBlock => b.type === 'text')
      .map((b) => b.text)
      .join('')
      .trim();

    return parseAnalysis(text, this.model, !!itemPhoto);
  }
}

function parseAnalysis(text: string, model: string, hadItemPhoto: boolean): ReceiptAnalysis {
  // The model is asked for bare JSON, but tolerate a ```json fence just in case.
  const jsonSlice = text.replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
  let raw: unknown;
  try {
    raw = JSON.parse(jsonSlice);
  } catch {
    return neutral(model, 'The analysis response could not be parsed.', hadItemPhoto);
  }

  const obj = raw as Record<string, unknown>;
  const risk: ReceiptRisk =
    obj.risk === 'high' || obj.risk === 'medium' || obj.risk === 'low' ? obj.risk : 'low';
  const ex = (obj.extracted ?? {}) as Record<string, unknown>;
  const assessment = obj.itemPhotoAssessment;
  const itemPhotoAssessment: ItemPhotoAssessment =
    assessment === 'match' || assessment === 'mismatch' || assessment === 'unclear'
      ? assessment
      : hadItemPhoto
        ? 'unclear'
        : 'not_provided';

  return {
    risk,
    summary: typeof obj.summary === 'string' ? obj.summary : '',
    flags: Array.isArray(obj.flags) ? obj.flags.filter((f): f is string => typeof f === 'string') : [],
    extracted: {
      merchant: str(ex.merchant),
      merchantOriginal: str(ex.merchantOriginal),
      date: str(ex.date),
      currency: str(ex.currency),
      total: str(ex.total),
      items: Array.isArray(ex.items) ? ex.items.filter((i): i is string => typeof i === 'string') : [],
      language: str(ex.language),
    },
    itemPhotoAssessment,
    model,
    analyzedAt: new Date().toISOString(),
  };
}

function neutral(model: string, summary: string, hadItemPhoto: boolean): ReceiptAnalysis {
  return {
    risk: 'low',
    summary,
    flags: [],
    extracted: {
      merchant: null,
      merchantOriginal: null,
      date: null,
      currency: null,
      total: null,
      items: [],
      language: null,
    },
    itemPhotoAssessment: hadItemPhoto ? 'unclear' : 'not_provided',
    model,
    analyzedAt: new Date().toISOString(),
  };
}

function str(v: unknown): string | null {
  return typeof v === 'string' && v.trim() !== '' ? v.trim() : null;
}
