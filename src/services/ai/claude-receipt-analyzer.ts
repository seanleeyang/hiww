import Anthropic from '@anthropic-ai/sdk';
import type {
  ReceiptAnalyzer,
  ReceiptAnalysisInput,
  ReceiptAnalysis,
  ReceiptRisk,
} from './types';
import { fetchImage } from './fetch-image';

const SYSTEM = `You review photos of shop receipts for a cross-border shopping marketplace.
A traveller has bought an item for a shopper and uploaded the receipt as proof of purchase.
Your job is to help a human operator spot problems — you never make the final call.

Return ONLY a JSON object, no prose, with exactly these keys:
{
  "risk": "low" | "medium" | "high",
  "summary": string,            // one or two sentences for the operator
  "flags": string[],            // specific concerns; [] if nothing stands out
  "extracted": {
    "merchant": string | null,
    "date": string | null,      // as printed on the receipt
    "currency": string | null,
    "total": string | null,     // numeric string
    "items": string[]
  }
}

Raise the risk when: the image looks edited, screenshotted, or is not a photo of a
paper receipt; the receipt total is far from the amount the shopper paid; the
printed date is before the order was placed or implausibly old; the items on the
receipt do not match what was requested; the receipt is unreadable or clearly not
a purchase receipt. "low" means nothing notable, "medium" means one soft concern,
"high" means a clear red flag.`;

export class ClaudeReceiptAnalyzer implements ReceiptAnalyzer {
  private readonly client: Anthropic;

  constructor(
    apiKey: string,
    private readonly model: string
  ) {
    this.client = new Anthropic({ apiKey });
  }

  async analyze(input: ReceiptAnalysisInput): Promise<ReceiptAnalysis> {
    const { data, mediaType } = await fetchImage(input.imageUrl);

    const userText = [
      `Item requested: ${input.itemDescription}`,
      `Amount the shopper paid: ${input.expectedAmount}`,
      `Buy-in country: ${input.sourceCountry ?? 'unknown'}`,
      `Order placed: ${input.orderCreatedAt.toISOString()}`,
      'Analyse the attached receipt.',
    ].join('\n');

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
            { type: 'image', source: { type: 'base64', media_type: mediaType, data } },
            { type: 'text', text: userText },
          ],
        },
      ],
    });

    if (response.stop_reason === 'refusal') {
      return neutral(this.model, 'The model declined to analyse this image.');
    }

    const text = response.content
      .filter((b): b is Anthropic.Beta.BetaTextBlock => b.type === 'text')
      .map((b) => b.text)
      .join('')
      .trim();

    return parseAnalysis(text, this.model);
  }
}

function parseAnalysis(text: string, model: string): ReceiptAnalysis {
  // The model is asked for bare JSON, but tolerate a ```json fence just in case.
  const jsonSlice = text.replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
  let raw: unknown;
  try {
    raw = JSON.parse(jsonSlice);
  } catch {
    return neutral(model, 'The analysis response could not be parsed.');
  }

  const obj = raw as Record<string, unknown>;
  const risk: ReceiptRisk =
    obj.risk === 'high' || obj.risk === 'medium' || obj.risk === 'low' ? obj.risk : 'low';
  const ex = (obj.extracted ?? {}) as Record<string, unknown>;

  return {
    risk,
    summary: typeof obj.summary === 'string' ? obj.summary : '',
    flags: Array.isArray(obj.flags) ? obj.flags.filter((f): f is string => typeof f === 'string') : [],
    extracted: {
      merchant: str(ex.merchant),
      date: str(ex.date),
      currency: str(ex.currency),
      total: str(ex.total),
      items: Array.isArray(ex.items) ? ex.items.filter((i): i is string => typeof i === 'string') : [],
    },
    model,
    analyzedAt: new Date().toISOString(),
  };
}

function neutral(model: string, summary: string): ReceiptAnalysis {
  return {
    risk: 'low',
    summary,
    flags: [],
    extracted: { merchant: null, date: null, currency: null, total: null, items: [] },
    model,
    analyzedAt: new Date().toISOString(),
  };
}

function str(v: unknown): string | null {
  return typeof v === 'string' && v.trim() !== '' ? v.trim() : null;
}
