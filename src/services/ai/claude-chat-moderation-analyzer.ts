import Anthropic from '@anthropic-ai/sdk';
import type {
  ChatModerationAnalyzer,
  ChatModerationInput,
  ChatModerationResult,
  ModerationRisk,
} from './chat-moderation-types';

const SYSTEM = `You moderate one chat message sent between a shopper and a traveller on a
cross-border shopping marketplace. Your job is to help a human operator spot problems —
you never take action yourself, and the message is always sent regardless of your answer.

Return ONLY a JSON object, no prose, with exactly these keys:
{
  "risk": "low" | "medium" | "high",
  "reasons": string[],   // specific concerns; [] if nothing stands out
  "summary": string      // one sentence for the operator
}

Raise the risk when the message tries to move the deal off the platform (asking for or
sharing a phone number, email, or a WhatsApp/Line/Telegram/WeChat/Signal/Instagram handle;
proposing to pay or be paid outside the app); or when the message is abusive, harassing,
threatening, or sexually inappropriate. "low" means nothing notable, "medium" means one
soft concern (e.g. an ambiguous mention that might be innocent), "high" means a clear,
unambiguous case.`;

export class ClaudeChatModerationAnalyzer implements ChatModerationAnalyzer {
  private readonly client: Anthropic;

  constructor(
    apiKey: string,
    private readonly model: string
  ) {
    this.client = new Anthropic({ apiKey });
  }

  async analyze(input: ChatModerationInput): Promise<ChatModerationResult> {
    const response = await this.client.messages.create({
      model: this.model,
      max_tokens: 512,
      system: SYSTEM,
      messages: [{ role: 'user', content: `Message: ${input.body}` }],
    });

    const text = response.content
      .filter((b): b is Anthropic.TextBlock => b.type === 'text')
      .map((b) => b.text)
      .join('')
      .trim();

    return parseResult(text, this.model);
  }
}

function parseResult(text: string, model: string): ChatModerationResult {
  // The model is asked for bare JSON, but tolerate a ```json fence just in case.
  const jsonSlice = text.replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
  let raw: unknown;
  try {
    raw = JSON.parse(jsonSlice);
  } catch {
    return neutral(model, 'The moderation response could not be parsed.');
  }

  const obj = raw as Record<string, unknown>;
  const risk: ModerationRisk =
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

function neutral(model: string, summary: string): ChatModerationResult {
  return { risk: 'low', reasons: [], summary, model, analyzedAt: new Date().toISOString() };
}
