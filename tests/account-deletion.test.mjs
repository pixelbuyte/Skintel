import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash, generateKeyPairSync, verify } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { afterEach, beforeEach, test } from 'node:test';

// Compile the actual API, including files excluded from the web tsconfig. No live APIs.
execFileSync(process.execPath, [
  'node_modules/typescript/bin/tsc', '--ignoreConfig', '--module', 'NodeNext', '--moduleResolution', 'NodeNext',
  '--target', 'ES2023', '--strict', '--skipLibCheck', '--noEmitOnError',
  '--outDir', 'node_modules/.cache/account-tests', '--rootDir', 'api', 'api/account.ts',
], { stdio: 'inherit' });
writeFileSync('node_modules/.cache/account-tests/package.json', '{"type":"module"}');
const { default: handler } = await import('../node_modules/.cache/account-tests/account.js');

const nonce = 'a-fresh-random-confirmation-nonce';
const userID = '11111111-1111-4111-8111-111111111111';
const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const appleIdentity = { provider: 'apple', id: 'apple-subject', identity_data: { sub: 'apple-subject' } };
const emailIdentity = { provider: 'email', id: userID, identity_data: { sub: userID } };
let user, calls, tokenClaims, tokenStatus, revokeStatus, deleteStatus, unauthorized;
const originalFetch = globalThis.fetch;
const envKeys = [
  'SUPABASE_URL', 'VITE_SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY',
  'APPLE_SIGN_IN_TEAM_ID', 'APPLE_SIGN_IN_KEY_ID', 'APPLE_SIGN_IN_PRIVATE_KEY',
];
const savedEnv = new Map(envKeys.map((key) => [key, process.env[key]]));
const reply = (body, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { 'content-type': 'application/json' },
});

beforeEach(() => {
  user = { id: userID, app_metadata: { provider: 'apple', providers: ['apple'] }, identities: [appleIdentity] };
  calls = [];
  tokenClaims = {
    iss: 'https://appleid.apple.com', aud: 'com.skintel.app', sub: 'apple-subject',
    exp: Math.floor(Date.now() / 1000) + 300,
    nonce: createHash('sha256').update(nonce).digest('hex'),
  };
  tokenStatus = revokeStatus = deleteStatus = 200;
  unauthorized = false;
  process.env.SUPABASE_URL = process.env.VITE_SUPABASE_URL = 'https://supabase.invalid';
  process.env.SUPABASE_SERVICE_ROLE_KEY = 'test-service-role';
  process.env.APPLE_SIGN_IN_TEAM_ID = 'TESTTEAM';
  process.env.APPLE_SIGN_IN_KEY_ID = 'TESTKEY';
  process.env.APPLE_SIGN_IN_PRIVATE_KEY = privateKey.export({ type: 'pkcs8', format: 'pem' });
  globalThis.fetch = async (input, init = {}) => {
    const url = String(input);
    calls.push({ url, method: init.method, body: init.body });
    if (url === 'https://supabase.invalid/auth/v1/user') {
      return unauthorized ? reply({ message: 'Unauthorized' }, 401) : reply(user);
    }
    if (url === 'https://appleid.apple.com/auth/token') {
      if (tokenStatus !== 200) return reply({ error: 'invalid_grant', detail: 'must not leak' }, tokenStatus);
      const payload = Buffer.from(JSON.stringify(tokenClaims)).toString('base64url');
      return reply({ refresh_token: 'test-refresh-token', id_token: `header.${payload}.signature` });
    }
    if (url === 'https://appleid.apple.com/auth/revoke') {
      return new Response(null, { status: revokeStatus });
    }
    if (url === `https://supabase.invalid/auth/v1/admin/users/${userID}`) {
      assert.equal(init.method, 'DELETE');
      return deleteStatus === 200 ? reply({ user }) : reply({ message: 'database error' }, deleteStatus);
    }
    throw new Error(`Unexpected network call: ${url}`);
  };
});

afterEach(() => {
  globalThis.fetch = originalFetch;
  for (const [key, value] of savedEnv) {
    if (value === undefined) delete process.env[key]; else process.env[key] = value;
  }
});

async function request(action = 'delete', body = { appleAuthorizationCode: 'fresh-code', appleNonce: nonce }, method = 'POST') {
  const result = { status: 200, headers: {}, body: null };
  const res = {
    status(value) { result.status = value; return this; },
    setHeader(key, value) { result.headers[key] = value; return this; },
    send(value) { result.body = JSON.parse(value); return this; },
  };
  await handler({ query: { action }, headers: { authorization: 'Bearer test-session' }, body, method }, res);
  return result;
}
const mutations = () => calls.filter((item) => item.url.includes('/auth/revoke') || item.method === 'DELETE');

test('Apple authorization is exchanged, bound to the account and revoked before the one hard delete', async () => {
  const result = await request();
  assert.equal(result.status, 200);
  assert.deepEqual(result.body, { ok: true });
  assert.deepEqual(calls.map((item) => item.url), [
    'https://supabase.invalid/auth/v1/user', 'https://appleid.apple.com/auth/token',
    'https://appleid.apple.com/auth/revoke', `https://supabase.invalid/auth/v1/admin/users/${userID}`,
  ]);
  const exchange = new URLSearchParams(calls[1].body);
  assert.equal(exchange.get('client_id'), 'com.skintel.app');
  assert.equal(exchange.get('code'), 'fresh-code');
  assert.equal(exchange.get('grant_type'), 'authorization_code');
  const secret = exchange.get('client_secret');
  const [header, payload, signature] = secret.split('.');
  assert.equal(JSON.parse(Buffer.from(header, 'base64url')).alg, 'ES256');
  assert.deepEqual(JSON.parse(Buffer.from(payload, 'base64url')).sub, 'com.skintel.app');
  assert(verify('sha256', Buffer.from(`${header}.${payload}`), {
    key: publicKey, dsaEncoding: 'ieee-p1363',
  }, Buffer.from(signature, 'base64url')));
  const revocation = new URLSearchParams(calls[2].body);
  assert.equal(revocation.get('token'), 'test-refresh-token');
  assert.equal(revocation.get('token_type_hint'), 'refresh_token');
  assert.equal(result.headers['Cache-Control'], 'no-store');
});

test('email-only accounts delete without any Apple credentials or Apple requests', async () => {
  user = { ...user, identities: [emailIdentity], app_metadata: { provider: 'email', providers: ['email'] } };
  delete process.env.APPLE_SIGN_IN_PRIVATE_KEY;
  const result = await request('delete', {});
  assert.equal(result.status, 200);
  assert.equal(calls.length, 2);
  assert.equal(calls[1].method, 'DELETE');
});

test('linked Apple identities still require revocation when email is the primary provider', async () => {
  user.app_metadata = { provider: 'email', providers: ['email', 'apple'] };
  user.identities = [emailIdentity, appleIdentity];
  const result = await request('delete', {});
  assert.equal(result.status, 409);
  assert.deepEqual(mutations(), []);
});

test('no body / old client cannot silently delete an Apple account', async () => {
  const result = await request('delete', null);
  assert.equal(result.status, 409);
  assert.deepEqual(mutations(), []);
});

test('user-editable metadata cannot skip Apple revocation', async () => {
  user.user_metadata = { provider: 'email', providers: ['email'] };
  const result = await request('delete', {});
  assert.equal(result.status, 409);
  assert.deepEqual(mutations(), []);
});

test('incomplete server identities do not permit a revocation bypass', async () => {
  user.identities = [];
  const result = await request('delete', {});
  assert.equal(result.status, 503);
  assert.deepEqual(mutations(), []);
});

for (const [name, change] of [
  ['wrong Apple user', () => { tokenClaims.sub = 'another-apple-account'; }],
  ['wrong audience', () => { tokenClaims.aud = 'another-app'; }],
  ['wrong issuer', () => { tokenClaims.iss = 'https://attacker.invalid'; }],
  ['wrong nonce', () => { tokenClaims.nonce = 'old-confirmation'; }],
  ['expired identity', () => { tokenClaims.exp = 0; }],
]) {
  test(`${name} cannot revoke or delete either account`, async () => {
    change();
    const result = await request();
    assert.equal(result.status, 409);
    assert.deepEqual(mutations(), []);
  });
}

test('unconfigured Apple key prevents deletion and is detected before the client prompts', async () => {
  delete process.env.APPLE_SIGN_IN_PRIVATE_KEY;
  const requirements = await request('deletion-requirements', undefined, 'GET');
  assert.equal(requirements.status, 503);
  const result = await request();
  assert.equal(result.status, 503);
  assert.deepEqual(mutations(), []);
});

test('expired or reused Apple authorization code preserves all account data', async () => {
  tokenStatus = 400;
  const result = await request();
  assert.equal(result.status, 409);
  assert(!JSON.stringify(result).includes('must not leak'));
  assert.deepEqual(mutations(), []);
});

test('Apple revocation error stops the auth/database delete', async () => {
  revokeStatus = 500;
  const result = await request();
  assert.equal(result.status, 503);
  assert.equal(calls.filter((item) => item.method === 'DELETE').length, 0);
});

test('auth delete failure has no preceding partial row deletion and returns an error', async () => {
  deleteStatus = 500;
  const result = await request();
  assert.equal(result.status, 500);
  assert.equal(calls.filter((item) => item.method === 'DELETE').length, 1);
  assert(!JSON.stringify(result).includes('database error'));
});

test('preflight returns the verified Apple identity; email accounts need no confirmation', async () => {
  assert.deepEqual((await request('deletion-requirements', undefined, 'GET')).body, { appleUserID: 'apple-subject' });
  user = { ...user, identities: [emailIdentity], app_metadata: { providers: ['email'] } };
  assert.deepEqual((await request('deletion-requirements', undefined, 'GET')).body, { appleUserID: null });
  assert.deepEqual(mutations(), []);
});

test('unauthenticated callers never reach Apple or deletion', async () => {
  unauthorized = true;
  const result = await request();
  assert.equal(result.status, 401);
  assert.deepEqual(mutations(), []);
});

test('ambiguous action and wrong method are rejected before any network request', async () => {
  assert.equal((await request(['delete', 'export'])).status, 400);
  assert.equal((await request('delete', undefined, 'GET')).status, 405);
  assert.equal(calls.length, 0);
});
