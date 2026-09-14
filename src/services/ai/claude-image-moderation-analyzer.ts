import Anthropic from '@anthropic-ai/sdk';
import type {
  ImageModerationAnalyzer,
  ImageModerationInput,
  ImageModerationResult,
  ImageModerationRisk,
} from './image-moderation-types';

const SYSTEM = `You screen one photo uploaded to a peer-to-peer cross-border shopping
marketplace (want/item photos, trip cover photos, profile pictures) before it becomes
publicly visible to other users. Your job is to help a human operator catch content that
should never go public — you never take any action yourself.

Return ONLY a JSON object, no prose, with exactly these keys:
{
  "risk": "low" | "medium" | "high",
  "reasons": string[],   // specific concerns; [] if nothing stands out
  "summary": string      // one sentence for the operator
}

"high" means the image is unambiguously sexually explicit, graphic/violent, or otherwise
clearly inappropriate for a public marketplace listing — reserve this for clear-cut cases
only. "medium" means something borderline or ambiguous an operator should take a quick
look at (e.g. partial nudity that could be a swimwear/fashion photo, something that looks
staged or out of place for the stated purpose). "low" means an ordinary photo — a product,
a travel scene, a portrait, a screenshot, packaging, a receipt, an ID document, anything
unremarkable. Most photos are "low" — do not over-flag ordinary content.`;

export class ClaudeImageModerationAnalyzer implements ImageModerationAnalyzer {
  private readonly client: Anthropic;

  constructor(
    apiKey: string,
    private readonly model: string
  ) {
    // See claude-chat-moderation-analyzer.ts — bound a stuck upstream call
    // rather than inherit the SDK's multi-minute default. Unlike the other
    // analyzers this one sits in the upload request's critical path (see
    // src/modules/uploads/routes.ts), so a slow response directly delays
    // the user, not just a background task — keep it well under the
    // request's own rate-limit window.
    this.client = new Anthropic({ apiKey, timeout: 20_000 });
  }

  async analyze(input: ImageModerationInput): Promise<ImageModerationResult> {
    const response = await this.client.messages.create({
      model: this.model,
      max_tokens: 300,
      system: SYSTEM,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: { type: 'base64', media_type: input.mimeType, data: input.data.toString('base64') },
            },
          ],
        },
      ],
    });

    const text = response.content
      .filter((b): b is Anthropic.TextBlock => b.type === 'text')
      .map((b) => b.text)
      .join('')
      .trim();

    return parseResult(text, this.model);
  }
}

function parseResult(text: string, model: string): ImageModerationResult {
  // The model is asked for bare JSON, but tolerate a ```json fence just in case.
  const jsonSlice = text.replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
  let raw: unknown;
  try {
    raw = JSON.parse(jsonSlice);
  } catch {
    // A parse failure must never block a legitimate upload — treat it the
    // same as "nothing stood out" and let the operator's other tools (user
    // reports, spot checks) catch anything this missed.
    return neutral(model, 'The moderation response could not be parsed.');
  }

  const obj = raw as Record<string, unknown>;
  const risk: ImageModerationRisk =
    obj.risk === 'high' || obj.risk === 'medium' || obj.risk === 'low' ? obj.risk : 'low';

  return {
    risk,
    reasons: Array.isArray(obj.reasons)
      ? obj.reasons.filter((r): r is string => typeof r === 'string')
      : [],
    summary: typeof obj.summary === 'string' ? obj.summary : '',
    model,
    analyzedAt: new Date().toISOString(),
  };
}

function neutral(model: string, summary: string): ImageModerationResult {
  return { risk: 'low', reasons: [], summary, model, analyzedAt: new Date().toISOString() };
}
