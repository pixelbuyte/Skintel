// Offline regression tests against the actual API source, with network/AI/database
// boundaries replaced. No production credentials, network requests, or paid calls.
// Run after npm ci: node --test scripts/test-scan-pipeline.cjs
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');
const cheerio = require('cheerio');

function loadAPI(filename, { fetch, create, cached = null, now = () => Date.now(), extra = '' } = {}) {
  const requests = [];
  const clients = [];
  class Anthropic {
    constructor(options) {
      clients.push(options);
      this.messages = { create: async (body, options) => {
        requests.push({ body, options });
        return create ? create(body, options) : { content: [{ type: 'text', text: '{"ingredients":"Aqua"}' }], usage: {} };
      } };
    }
  }
  const sb = { from(table) {
    const data = table === 'subscriptions' ? { tier: 'pro', status: 'active' }
      : table === 'barcode_cache' ? cached : [];
    const chain = {
      select: () => chain, eq: () => chain,
      maybeSingle: async () => ({ data }),
      upsert: async () => ({ data: null }),
      then: (resolve, reject) => Promise.resolve({ data }).then(resolve, reject),
    };
    return chain;
  } };
  const lib = {
    getUserFromAuthHeader: async () => ({ id: 'test-user' }),
    getServiceClient: () => sb,
    json: (res, body, status = 200) => { res.body = body; res.status = status; return res; },
  };
  const source = fs.readFileSync(path.join(__dirname, '..', 'api', filename), 'utf8') + extra;
  const transpiled = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS, esModuleInterop: true } });
  const module = { exports: {} };
  vm.runInNewContext(transpiled.outputText, {
    module, exports: module.exports,
    require: name => name === '@anthropic-ai/sdk' ? Anthropic : name === './_lib.js' ? lib : require(name),
    process: { env: { ANTHROPIC_API_KEY: 'offline-test-placeholder' } },
    fetch: fetch || (() => { throw new Error('Unexpected network request'); }),
    URL, AbortController, setTimeout, clearTimeout, Uint8Array, TextDecoder,
    Date: { now }, console: { error() {} },
  }, { filename });
  return { api: module.exports, clients, requests };
}

test('cached barcode ingredients return immediately without catalogue or model calls', async () => {
  const fixture = loadAPI('_barcode-lookup.ts', { cached: { brand: 'Known', product_name: 'Cleanser', ingredients: 'Aqua', source: 'openbeautyfacts' } });
  const res = {};
  await fixture.api.default({ method: 'GET', query: { upc: '1234567890123' } }, res);
  assert.equal(res.status, 200);
  assert.equal(res.body.source, 'cache');
  assert.equal(res.body.ingredients, 'Aqua');
  assert.equal(fixture.requests.length, 0);
});

test('cold catalogue requests start together and carry the exact product photo', async () => {
  const pending = [];
  const fixture = loadAPI('_barcode-lookup.ts', {
    fetch: url => new Promise(resolve => pending.push({ url, resolve })),
  });
  const res = {};
  const job = fixture.api.default({ method: 'GET', query: { upc: '1234567890123' } }, res);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(pending.length, 2, 'both catalogues must start before either responds');
  const beauty = pending.find(entry => entry.url.includes('openbeautyfacts'));
  const food = pending.find(entry => entry.url.includes('openfoodfacts'));
  food.resolve({ ok: true, json: async () => ({ status: 1, product: { brands: 'Other', product_name: 'Other', ingredients_text: 'Water' } }) });
  beauty.resolve({ ok: true, json: async () => ({ status: 1, product: { brands: 'Known', product_name: 'Cleanser', ingredients_text: 'Aqua, Glycerin', image_front_url: 'https://images.openbeautyfacts.org/cleanser.jpg' } }) });
  await job;
  assert.equal(res.status, 200);
  assert.equal(res.body.source, 'openbeautyfacts', 'beauty catalogue retains priority');
  assert.equal(res.body.imageUrl, 'https://images.openbeautyfacts.org/cleanser.jpg');
  assert.equal(fixture.requests.length, 0);
});

test('product page images require unambiguous product metadata', () => {
  const fixture = loadAPI('_import-url.ts', { extra: '\nexport { extractProductImage };' });
  const extract = html => fixture.api.extractProductImage(cheerio.load(html), new URL('https://brand.example/product'));
  assert.equal(extract('<script type="application/ld+json">{"@type":"Product","image":"/cleanser.jpg"}</script>'), 'https://brand.example/cleanser.jpg');
  assert.equal(extract('<meta property="og:image" content="https://brand.example/logo.jpg">'), undefined);
  assert.equal(extract('<script type="application/ld+json">[{"@type":"Product","image":"/one.jpg"},{"@type":"Product","image":"/two.jpg"}]</script>'), undefined);
  assert.equal(extract('<script type="application/ld+json">{"@type":"Product","image":"http://brand.example/one.jpg"}</script>'), undefined);
});

test('verdict fallback receives only the remaining deadline, without SDK retries', async () => {
  let now = 1000;
  let calls = 0;
  const fixture = loadAPI('scan-ai.ts', {
    now: () => now,
    create: async () => {
      if (++calls === 1) { now += 12000; throw new Error('Primary unavailable'); }
      return { content: [{ type: 'text', text: '{"verdict":"clean","score":90,"summary":"ok","flags":[]}' }], usage: {} };
    },
  });
  const res = {};
  await fixture.api.default({ method: 'POST', body: { inci: 'Aqua, Glycerin' } }, res);
  assert.equal(res.status, 200);
  assert.equal(fixture.clients[0].maxRetries, 0);
  assert.equal(fixture.requests[0].options.timeout, 35000);
  assert.equal(fixture.requests[1].options.timeout, 23000);
  assert.equal(fixture.requests[0].body.model, 'claude-opus-4-8');
  assert.equal(fixture.requests[1].body.model, 'claude-sonnet-4-6');
});

test('an exhausted verdict deadline never starts another paid model call', async () => {
  let now = 1000;
  const fixture = loadAPI('scan-ai.ts', { now: () => now, create: async () => { now += 35000; throw new Error('Timeout'); } });
  const res = {};
  await fixture.api.default({ method: 'POST', body: { inci: 'Aqua' } }, res);
  assert.equal(res.status, 504);
  assert.equal(fixture.requests.length, 1);
});

test('photo OCR has one bounded attempt and preserves the OCR response contract', async () => {
  const fixture = loadAPI('scan-photo.ts');
  const res = {};
  await fixture.api.default({ method: 'POST', body: { imageBase64: 'aW1hZ2U=', mimeType: 'image/jpeg' } }, res);
  assert.equal(res.status, 200);
  assert.equal(res.body.result.ingredients, 'Aqua');
  assert.equal(fixture.clients[0].timeout, 20000);
  assert.equal(fixture.clients[0].maxRetries, 0);
});
