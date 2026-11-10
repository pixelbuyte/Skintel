import { createPrivateKey, sign } from 'node:crypto';
import { readFileSync } from 'node:fs';

const API_ORIGIN = 'https://api.appstoreconnect.apple.com';

type JsonApiResource = {
  id: string;
  type: string;
  attributes?: Record<string, unknown>;
  relationships?: Record<string, { data?: JsonApiResource | JsonApiResource[] }>;
};

type JsonApiDocument = {
  data: JsonApiResource | JsonApiResource[];
  included?: JsonApiResource[];
  links?: { next?: string | null };
};

function requiredEnvironment(name: 'ASC_ISSUER_ID' | 'ASC_KEY_ID' | 'ASC_PRIVATE_KEY_PATH'): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} must be set.`);
  return value;
}

function jwt(): string {
  const issuer = requiredEnvironment('ASC_ISSUER_ID');
  const keyId = requiredEnvironment('ASC_KEY_ID');
  const privateKey = createPrivateKey(readFileSync(requiredEnvironment('ASC_PRIVATE_KEY_PATH')));
  const encode = (value: object) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${encode({ alg: 'ES256', kid: keyId, typ: 'JWT' })}.${encode({ iss: issuer, iat: now, exp: now + 19 * 60, aud: 'appstoreconnect-v1' })}`;
  return `${unsigned}.${sign('sha256', Buffer.from(unsigned), { key: privateKey, dsaEncoding: 'ieee-p1363' }).toString('base64url')}`;
}

export class AscClient {
  async request<T = JsonApiDocument>(pathOrUrl: string, init: RequestInit = {}): Promise<T> {
    const url = pathOrUrl.startsWith('http') ? pathOrUrl : `${API_ORIGIN}${pathOrUrl}`;
    const response = await fetch(url, {
      ...init,
      headers: { Authorization: `Bearer ${jwt()}`, 'Content-Type': 'application/json', ...init.headers },
    });
    if (!response.ok) {
      const body = await response.text();
      throw new Error(`App Store Connect ${init.method ?? 'GET'} ${new URL(url).pathname} failed (${response.status}): ${body}`);
    }
    return response.json() as Promise<T>;
  }

  async list(path: string): Promise<JsonApiResource[]> {
    const result: JsonApiResource[] = [];
    let next: string | null | undefined = path;
    while (next) {
      const page: JsonApiDocument = await this.request<JsonApiDocument>(next);
      result.push(...(Array.isArray(page.data) ? page.data : [page.data]));
      next = page.links?.next;
    }
    return result;
  }
}

export type { JsonApiDocument, JsonApiResource };
