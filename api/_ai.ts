import Anthropic from '@anthropic-ai/sdk';

/**
 * One place that picks the model behind every scan. OpenRouter answers first, using cheap,
 * fast models with automatic fallback between them; the direct Anthropic key is used only
 * when OPENROUTER_API_KEY isn't set or OpenRouter fails, so scanning never goes dark.
 */

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

// Picked from OpenRouter's catalog for price per quality (Sep 2026). Tried in order.
export const SCAN_MODELS = ['google/gemini-3.1-flash-lite', 'openai/gpt-5.6-luna'] as const;
export const ANTHROPIC_FALLBACK_MODEL = 'claude-haiku-4-5-20251001';

export type AiImage = { base64: string; mimeType: string };

export type AiRequest = {
  models: readonly string[];
  system?: string;
  prompt: string;
  images?: AiImage[];
  maxTokens: number;
  temperature?: number;
  json?: boolean;
  webSearch?: boolean;
  timeoutMs?: number;
};

export type AiResult = { text: string; model: string; usage: unknown };

export class AiError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

type OpenRouterResponse = {
  model?: string;
  usage?: unknown;
  error?: { message?: string };
  choices?: { message?: { content?: unknown } }[];
};

/** Raw OpenRouter chat call. `models` is the ordered fallback list. */
export async function openRouterChat(
  apiKey: string,
  models: readonly string[],
  body: Record<string, unknown>,
  timeoutMs: number,
): Promise<AiResult> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const r = await fetch(OPENROUTER_URL, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://www.skinstel.com',
        'X-Title': 'Skintel',
      },
      body: JSON.stringify({ model: models[0], models, ...body }),
    });
    const data = (await r.json().catch(() => null)) as OpenRouterResponse | null;
    if (!r.ok) throw new AiError(data?.error?.message ?? `OpenRouter returned ${r.status}`, r.status);
    const text = data?.choices?.[0]?.message?.content;
    if (typeof text !== 'string' || !text.trim()) throw new AiError('Empty model reply', 502);
    return { text, model: data?.model ?? models[0], usage: data?.usage ?? null };
  } finally {
    clearTimeout(timer);
  }
}

async function viaOpenRouter(req: AiRequest, apiKey: string): Promise<AiResult> {
  const images = req.images ?? [];
  const content = images.length
    ? [
        ...images.map((img) => ({
          type: 'image_url',
          image_url: { url: `data:${img.mimeType};base64,${img.base64}` },
        })),
        { type: 'text', text: req.prompt },
      ]
    : req.prompt;
  const messages = [
    ...(req.system ? [{ role: 'system', content: req.system }] : []),
    { role: 'user', content },
  ];
  return openRouterChat(
    apiKey,
    req.models,
    {
      messages,
      max_tokens: req.maxTokens,
      temperature: req.temperature ?? 0,
      ...(req.json ? { response_format: { type: 'json_object' } } : {}),
      ...(req.webSearch ? { plugins: [{ id: 'web', max_results: 3 }] } : {}),
    },
    req.timeoutMs ?? 45_000,
  );
}

type AnthropicImageType = 'image/jpeg' | 'image/png' | 'image/gif' | 'image/webp';

async function viaAnthropic(req: AiRequest, apiKey: string): Promise<AiResult> {
  const client = new Anthropic({ apiKey });
  const content: Anthropic.ContentBlockParam[] = (req.images ?? []).map((img) => ({
    type: 'image' as const,
    source: { type: 'base64' as const, media_type: img.mimeType as AnthropicImageType, data: img.base64 },
  }));
  content.push({ type: 'text', text: req.prompt });
  const resp = await client.messages.create({
    model: ANTHROPIC_FALLBACK_MODEL,
    max_tokens: req.maxTokens,
    system: req.system,
    tools: req.webSearch ? [{ type: 'web_search_20250305', name: 'web_search', max_uses: 4 }] : undefined,
    messages: [{ role: 'user', content }],
  });
  const text = resp.content
    .filter((b): b is Anthropic.TextBlock => b.type === 'text')
    .map((b) => b.text)
    .join('');
  return { text, model: ANTHROPIC_FALLBACK_MODEL, usage: resp.usage };
}

export async function complete(req: AiRequest): Promise<AiResult> {
  const openRouterKey = process.env.OPENROUTER_API_KEY;
  const anthropicKey = process.env.ANTHROPIC_API_KEY;
  if (openRouterKey) {
    try {
      return await viaOpenRouter(req, openRouterKey);
    } catch (e) {
      console.error('openrouter request failed', { models: req.models, message: String((e as Error)?.message ?? e) });
      if (!anthropicKey) throw e;
    }
  }
  if (!anthropicKey) throw new AiError('No AI provider is configured', 503);
  return viaAnthropic(req, anthropicKey);
}

/** Models sometimes wrap JSON in fences or a sentence; take the object either way. */
export function parseJsonObject(text: string): unknown {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const candidate = fenced ? fenced[1] : (text.match(/\{[\s\S]*\}/)?.[0] ?? text);
  return JSON.parse(candidate);
}
