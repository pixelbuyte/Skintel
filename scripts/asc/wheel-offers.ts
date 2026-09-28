// Creates the "welcome wheel" subscription offer codes in App Store Connect.
//
//   node scripts/asc/wheel-offers.ts create [--dry-run]    create the 3 offers (idempotent)
//   node scripts/asc/wheel-offers.ts codes  [--dry-run]    generate one-time-use codes (run near launch)
//
// Needs Node >= 22.18 (runs .ts directly). No dependencies. See scripts/asc/README.md.
// Auth comes ONLY from env: ASC_ISSUER_ID, ASC_KEY_ID, ASC_PRIVATE_KEY_PATH. The key is never printed.
//
// Endpoints/fields checked against Apple's App Store Connect OpenAPI spec v4.5:
//   POST /v1/subscriptionOfferCodes, POST /v1/subscriptionOfferCodeOneTimeUseCodes,
//   GET  /v1/subscriptionOfferCodeOneTimeUseCodes/{id}/values (text/csv),
//   GET  /v1/subscriptions/{id}/pricePoints (filter[territory]), .../prices, .../offerCodes.

import { createPrivateKey, sign } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const BUNDLE_ID = 'com.skintel.app';
const PRODUCT_ID = 'com.skintel.app.pro.monthly'; // must match api/_apple.ts APPLE_PRODUCTS

type Mode = 'FREE_TRIAL' | 'PAY_AS_YOU_GO';
type OfferSpec = {
  name: string;
  offerMode: Mode;
  duration: 'THREE_DAYS' | 'ONE_WEEK' | 'ONE_MONTH';
  numberOfPeriods: number;
  discount?: number; // fraction off the monthly price (PAY_AS_YOU_GO only)
};

const OFFERS: OfferSpec[] = [
  { name: 'Wheel - 3 days free', offerMode: 'FREE_TRIAL', duration: 'THREE_DAYS', numberOfPeriods: 1 },
  { name: 'Wheel - 7 days free', offerMode: 'FREE_TRIAL', duration: 'ONE_WEEK', numberOfPeriods: 1 },
  {
    name: 'Wheel - 50% off first month',
    offerMode: 'PAY_AS_YOU_GO',
    duration: 'ONE_MONTH',
    numberOfPeriods: 1,
    discount: 0.5,
  },
];

// Fixed by the brief: new subscribers only, and do NOT combine with an introductory offer.
const CUSTOMER_ELIGIBILITIES = ['NEW'];
const OFFER_ELIGIBILITY = 'REPLACE_INTRO_OFFERS'; // the other value, STACK_WITH_INTRO_OFFERS, = "can combine: Yes"

const DEFAULT_CODES = 500;
const DEFAULT_EXPIRY_DAYS = 180;

// ---------- args ----------

const args = process.argv.slice(2);
const command = args[0] && !args[0].startsWith('--') ? args[0] : 'create';
const flag = (n: string) => args.includes(`--${n}`);
const opt = (n: string) => {
  const i = args.indexOf(`--${n}`);
  return i >= 0 ? args[i + 1] : undefined;
};
const DRY = flag('dry-run');
const VERBOSE = flag('verbose');

// ---------- auth + http ----------

const API = (() => {
  // Test hook only: lets the script talk to a local mock. Anything else is ignored.
  const o = process.env.ASC_API_BASE;
  return o && /^http:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/.test(o) ? o : 'https://api.appstoreconnect.apple.com';
})();

function loadCreds() {
  const need = ['ASC_ISSUER_ID', 'ASC_KEY_ID', 'ASC_PRIVATE_KEY_PATH'];
  const missing = need.filter((k) => !process.env[k]);
  if (missing.length) die(`Missing env vars: ${missing.join(', ')} (see scripts/asc/README.md)`);
  let pem: string;
  try {
    pem = readFileSync(process.env.ASC_PRIVATE_KEY_PATH as string, 'utf8');
  } catch {
    die('Cannot read the file at ASC_PRIVATE_KEY_PATH.');
  }
  let key;
  try {
    key = createPrivateKey(pem);
  } catch {
    die('ASC_PRIVATE_KEY_PATH is not a valid .p8 (PEM) private key.');
  }
  return { issuer: process.env.ASC_ISSUER_ID as string, kid: process.env.ASC_KEY_ID as string, key };
}

const creds = loadCreds();
let jwt = { token: '', exp: 0 };

function token(): string {
  const now = Math.floor(Date.now() / 1000);
  if (jwt.token && jwt.exp - now > 120) return jwt.token;
  const exp = now + 15 * 60; // Apple allows at most 20 minutes
  const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const head = b64({ alg: 'ES256', kid: creds.kid, typ: 'JWT' });
  const body = b64({ iss: creds.issuer, iat: now, exp, aud: 'appstoreconnect-v1' });
  const sig = sign('sha256', Buffer.from(`${head}.${body}`), { key: creds.key, dsaEncoding: 'ieee-p1363' });
  jwt = { token: `${head}.${body}.${sig.toString('base64url')}`, exp };
  return jwt.token;
}

class AscError extends Error {}

async function call(method: 'GET' | 'POST', pathOrUrl: string, body?: unknown, accept = 'application/json') {
  const url = pathOrUrl.startsWith('http') ? pathOrUrl : API + pathOrUrl;
  for (let attempt = 1; ; attempt++) {
    const res = await fetch(url, {
      method,
      headers: {
        Authorization: `Bearer ${token()}`,
        Accept: accept,
        ...(body ? { 'Content-Type': 'application/json' } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(60_000),
    });
    if ((res.status === 429 || res.status >= 500) && attempt < 5) {
      const wait = Number(res.headers.get('retry-after')) || 2 ** attempt;
      await new Promise((r) => setTimeout(r, wait * 1000));
      continue;
    }
    const text = await res.text();
    if (!res.ok) {
      let detail = text.slice(0, 600);
      try {
        const e = JSON.parse(text).errors?.map((x: { title?: string; detail?: string; code?: string }) =>
          [x.code, x.title, x.detail].filter(Boolean).join(': '),
        );
        if (e?.length) detail = e.join(' | ');
      } catch {
        /* keep raw text */
      }
      throw new AscError(`${method} ${url.replace(API, '')} -> ${res.status}: ${detail}`);
    }
    return accept === 'application/json' ? (text ? JSON.parse(text) : {}) : text;
  }
}

type Res = {
  id: string;
  type: string;
  attributes?: Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any
  relationships?: Record<string, { data?: { id: string; type: string } | null }>;
};
type Page = { data: Res[]; included?: Res[]; links?: { next?: string } };

async function getAll(path: string): Promise<{ data: Res[]; included: Res[] }> {
  const data: Res[] = [];
  const included: Res[] = [];
  let next: string | undefined = path;
  while (next) {
    const page: Page = await call('GET', next);
    data.push(...page.data);
    included.push(...(page.included ?? []));
    next = page.links?.next;
  }
  return { data, included };
}

function die(msg: string): never {
  console.error(`error: ${msg}`);
  process.exit(1);
}

const q = (o: Record<string, string>) => new URLSearchParams(o).toString();

// ---------- lookups ----------

async function findSubscription() {
  const apps = await getAll(`/v1/apps?${q({ 'filter[bundleId]': BUNDLE_ID, limit: '200' })}`);
  const app = apps.data.find((a) => a.attributes?.bundleId === BUNDLE_ID);
  if (!app) die(`No app with bundle id ${BUNDLE_ID} visible to this API key.`);
  const groups = await getAll(`/v1/apps/${app.id}/subscriptionGroups?limit=200`);
  const seen: string[] = [];
  for (const g of groups.data) {
    const subs = await getAll(`/v1/subscriptionGroups/${g.id}/subscriptions?limit=200`);
    for (const s of subs.data) {
      seen.push(s.attributes?.productId);
      if (s.attributes?.productId === PRODUCT_ID) return { app, group: g, sub: s };
    }
  }
  die(
    `Subscription ${PRODUCT_ID} not found in App Store Connect. Product ids seen: ${seen.join(', ') || '(none)'}. ` +
      'Product ids are permanent and must match exactly (s-k-i-n-t-e-l).',
  );
}

async function availableTerritories(subId: string): Promise<string[]> {
  let avail: Page;
  try {
    avail = await call('GET', `/v1/subscriptions/${subId}/subscriptionAvailability`);
  } catch (e) {
    if (e instanceof AscError && / 404:/.test(e.message)) {
      die('The subscription has no availability set yet (no territories). Set availability in App Store Connect first.');
    }
    throw e;
  }
  const id = (avail.data as unknown as Res).id;
  const t = await getAll(`/v1/subscriptionAvailabilities/${id}/availableTerritories?limit=200`);
  return t.data.map((x) => x.id).sort();
}

/** Current price (customerPrice) per territory for new subscribers. */
async function currentPrices(subId: string): Promise<Map<string, number>> {
  const { data, included } = await getAll(
    `/v1/subscriptions/${subId}/prices?${q({ include: 'subscriptionPricePoint,territory', limit: '200' })}`,
  );
  const point = new Map(
    included.filter((i) => i.type === 'subscriptionPricePoints').map((i) => [i.id, Number(i.attributes?.customerPrice)]),
  );
  const today = new Date().toISOString().slice(0, 10);
  const best = new Map<string, { start: string; price: number }>();
  for (const p of data) {
    if (p.attributes?.preserved) continue; // grandfathered price for existing subscribers
    const start: string = p.attributes?.startDate ?? '';
    if (start > today) continue; // scheduled future price
    const terr = p.relationships?.territory?.data?.id;
    const price = point.get(p.relationships?.subscriptionPricePoint?.data?.id ?? '');
    if (!terr || price === undefined || Number.isNaN(price)) continue;
    const cur = best.get(terr);
    if (!cur || start >= cur.start) best.set(terr, { start, price });
  }
  return new Map([...best].map(([k, v]) => [k, v.price]));
}

type Pick = { territory: string; pointId: string; base: number; price: number };

async function pickDiscountPoints(subId: string, territories: string[], discount: number): Promise<{ picks: Pick[]; skipped: string[] }> {
  const base = await currentPrices(subId);
  const picks: Pick[] = [];
  const skipped: string[] = [];
  const todo = territories.filter((t) => (base.has(t) ? true : (skipped.push(t), false)));
  let i = 0;
  const worker = async () => {
    while (i < todo.length) {
      const t = todo[i++];
      const b = base.get(t) as number;
      const { data } = await getAll(`/v1/subscriptions/${subId}/pricePoints?${q({ 'filter[territory]': t, limit: '8000' })}`);
      const target = b * (1 - discount);
      let chosen: { id: string; price: number } | undefined;
      for (const p of data) {
        const price = Number(p.attributes?.customerPrice);
        if (!(price > 0) || price >= b) continue; // must be a real discount
        if (
          !chosen ||
          Math.abs(price - target) < Math.abs(chosen.price - target) ||
          (Math.abs(price - target) === Math.abs(chosen.price - target) && price < chosen.price)
        ) {
          chosen = { id: p.id, price };
        }
      }
      if (chosen) picks.push({ territory: t, pointId: chosen.id, base: b, price: chosen.price });
      else skipped.push(t);
    }
  };
  await Promise.all(Array.from({ length: 5 }, worker));
  picks.sort((a, b) => a.territory.localeCompare(b.territory));
  return { picks, skipped: skipped.sort() };
}

async function existingOffers(subId: string): Promise<Res[]> {
  return (await getAll(`/v1/subscriptions/${subId}/offerCodes?limit=200`)).data;
}

function differences(o: Res, s: OfferSpec): string[] {
  const a = o.attributes ?? {};
  const d: string[] = [];
  if (a.offerMode !== s.offerMode) d.push(`mode ${a.offerMode}`);
  if (a.duration !== s.duration) d.push(`duration ${a.duration}`);
  if (a.numberOfPeriods !== s.numberOfPeriods) d.push(`periods ${a.numberOfPeriods}`);
  if (a.offerEligibility !== OFFER_ELIGIBILITY) d.push(`offerEligibility ${a.offerEligibility}`);
  if ([...(a.customerEligibilities ?? [])].sort().join() !== [...CUSTOMER_ELIGIBILITIES].sort().join())
    d.push(`customerEligibilities ${(a.customerEligibilities ?? []).join('+')}`);
  return d;
}

// ---------- create ----------

async function create() {
  const { sub } = await findSubscription();
  console.log(`Subscription ${PRODUCT_ID}: found (id ${sub.id}, state ${sub.attributes?.state}).`);
  const territories = await availableTerritories(sub.id);
  console.log(`Sold in ${territories.length} territories.`);
  const existing = await existingOffers(sub.id);
  console.log(`Existing offer codes on this subscription: ${existing.length}.\n`);

  let created = 0;
  for (const spec of OFFERS) {
    const have = existing.find((o) => o.attributes?.name === spec.name);
    if (have) {
      const d = differences(have, spec);
      console.log(`- "${spec.name}": already exists (id ${have.id}${have.attributes?.active === false ? ', inactive' : ''}) -> skip` +
        (d.length ? `  WARNING: differs from spec (${d.join('; ')}). Not modified.` : ''));
      continue;
    }

    let prices: { territory: string; pointId?: string }[];
    if (spec.discount !== undefined) {
      const { picks, skipped } = await pickDiscountPoints(sub.id, territories, spec.discount);
      if (!picks.length) die(`No price points found for "${spec.name}".`);
      prices = picks.map((p) => ({ territory: p.territory, pointId: p.pointId }));
      const pct = (r: number) => (r * 100).toFixed(0);
      const ratios = picks.map((p) => p.price / p.base);
      console.log(
        `- "${spec.name}": ${DRY ? 'would create' : 'creating'} ${spec.offerMode}, ${spec.numberOfPeriods} x ${spec.duration}, ${picks.length} territories; ` +
          `price is ${pct(Math.min(...ratios))}${Math.min(...ratios) === Math.max(...ratios) ? '' : '-' + pct(Math.max(...ratios))}% of monthly` +
          (skipped.length ? `; SKIPPED (no current price/price point): ${skipped.join(', ')}` : ''),
      );
      const shown = VERBOSE ? picks : picks.filter((p) => ['USA', 'GBR', 'DEU', 'CAN', 'AUS', 'JPN'].includes(p.territory));
      for (const p of shown) console.log(`    ${p.territory}: ${p.base} -> ${p.price}`);
      if (!VERBOSE) console.log('    (use --verbose for every territory)');
    } else {
      prices = territories.map((territory) => ({ territory }));
      console.log(`- "${spec.name}": ${DRY ? 'would create' : 'creating'} ${spec.offerMode}, ${spec.numberOfPeriods} x ${spec.duration}, ${prices.length} territories`);
    }

    if (DRY) continue;
    const local = (t: string) => '${price-' + t + '}';
    const res = await call('POST', '/v1/subscriptionOfferCodes', {
      data: {
        type: 'subscriptionOfferCodes',
        attributes: {
          name: spec.name,
          customerEligibilities: CUSTOMER_ELIGIBILITIES,
          offerEligibility: OFFER_ELIGIBILITY,
          duration: spec.duration,
          offerMode: spec.offerMode,
          numberOfPeriods: spec.numberOfPeriods,
        },
        relationships: {
          subscription: { data: { type: 'subscriptions', id: sub.id } },
          prices: { data: prices.map((p) => ({ type: 'subscriptionOfferCodePrices', id: local(p.territory) })) },
        },
      },
      included: prices.map((p) => ({
        type: 'subscriptionOfferCodePrices',
        id: local(p.territory),
        relationships: {
          territory: { data: { type: 'territories', id: p.territory } },
          // Free trials carry no price point (the field is optional in the API schema).
          ...(p.pointId ? { subscriptionPricePoint: { data: { type: 'subscriptionPricePoints', id: p.pointId } } } : {}),
        },
      })),
    });
    created++;
    console.log(`    created (id ${(res.data as Res).id})`);
  }
  console.log(DRY ? '\nDry run: nothing was created.' : `\nDone. Created ${created} offer(s).`);
}

// ---------- one-time-use codes ----------

async function codes() {
  const count = Number(opt('count') ?? DEFAULT_CODES);
  if (!Number.isInteger(count) || count < 1) die('--count must be a positive integer.');
  const expires =
    opt('expires') ?? new Date(Date.now() + DEFAULT_EXPIRY_DAYS * 86_400_000).toISOString().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(expires) || expires <= new Date().toISOString().slice(0, 10))
    die('--expires must be a future date, YYYY-MM-DD.');
  const environment = flag('sandbox') ? 'SANDBOX' : 'PRODUCTION';

  const { sub } = await findSubscription();
  const existing = await existingOffers(sub.id);
  const outDir = join(dirname(fileURLToPath(import.meta.url)), 'out');

  for (const spec of OFFERS) {
    const offer = existing.find((o) => o.attributes?.name === spec.name);
    if (!offer) die(`Offer "${spec.name}" does not exist. Run the create command first.`);
    const batches = (await getAll(`/v1/subscriptionOfferCodes/${offer.id}/oneTimeUseCodes?limit=200`)).data.filter(
      (b) => b.attributes?.active && b.attributes?.environment === environment,
    );
    if (batches.length && !flag('allow-another-batch')) {
      console.log(`- "${spec.name}": ${batches.length} active ${environment} batch(es) already exist -> skip (--allow-another-batch to add more)`);
      continue;
    }
    console.log(`- "${spec.name}": ${DRY ? 'would generate' : 'generating'} ${count} ${environment} codes, expiring ${expires}`);
    if (DRY) continue;

    const res = await call('POST', '/v1/subscriptionOfferCodeOneTimeUseCodes', {
      data: {
        type: 'subscriptionOfferCodeOneTimeUseCodes',
        attributes: { numberOfCodes: count, expirationDate: expires, environment },
        relationships: { offerCode: { data: { type: 'subscriptionOfferCodes', id: offer.id } } },
      },
    });
    const batchId = (res.data as Res).id;
    let csv = '';
    for (let i = 0; i < 4 && !csv.trim(); i++) {
      try {
        csv = await call('GET', `/v1/subscriptionOfferCodeOneTimeUseCodes/${batchId}/values`, undefined, 'text/csv');
      } catch (e) {
        if (i === 3) console.error(`    could not download values yet (${(e as Error).message}); get them from App Store Connect.`);
      }
      if (!csv.trim()) await new Promise((r) => setTimeout(r, 3000));
    }
    if (csv.trim()) {
      mkdirSync(outDir, { recursive: true });
      const slug = spec.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
      const file = join(outDir, `${slug}-${expires}.csv`);
      writeFileSync(file, csv, { mode: 0o600 });
      console.log(`    batch ${batchId}: ${csv.trim().split('\n').length} lines saved to ${file}`);
    } else {
      console.log(`    batch ${batchId} created; values not downloaded.`);
    }
  }
  console.log(DRY ? '\nDry run: no codes were generated.' : '\nDone. Code files are in scripts/asc/out/ (gitignored). Treat them as secrets.');
}

// ---------- main ----------

try {
  if (DRY) console.log('DRY RUN: read-only requests only.\n');
  if (command === 'create') await create();
  else if (command === 'codes') await codes();
  else die(`Unknown command "${command}". Use "create" or "codes".`);
} catch (e) {
  die(e instanceof Error ? e.message : String(e));
}
