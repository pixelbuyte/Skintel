import { AscClient, type JsonApiDocument, type JsonApiResource } from './asc-client.ts';

const BUNDLE_ID = 'com.skintel.app';
const PRODUCTS = {
  monthly: 'com.skintel.app.pro.monthly',
  yearly: 'com.skintel.app.pro.yearly',
  founding: 'com.skintel.app.founding',
} as const;

const OFFERS = [
  { name: 'Wheel - 3 days free', duration: 'THREE_DAYS', offerMode: 'FREE_TRIAL' },
  { name: 'Wheel - 7 days free', duration: 'ONE_WEEK', offerMode: 'FREE_TRIAL' },
  { name: 'Wheel - 50% off first month', duration: 'ONE_MONTH', offerMode: 'PAY_AS_YOU_GO' },
] as const;

const dryRun = process.argv.includes('--dry-run');

function help(): never {
  console.log('Usage: node --experimental-strip-types scripts/asc/wheel-offers.ts [--dry-run]');
  process.exit(0);
}

function attributes(resource: JsonApiResource): Record<string, unknown> {
  return resource.attributes ?? {};
}

function relatedId(resource: JsonApiResource, name: string): string {
  const data = resource.relationships?.[name]?.data;
  if (!data || Array.isArray(data)) throw new Error(`Missing ${name} relationship on ${resource.type}/${resource.id}.`);
  return data.id;
}

async function appAndProducts(client: AscClient) {
  const apps = await client.list(`/v1/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}&fields[apps]=bundleId,name&limit=1`);
  if (apps.length !== 1) throw new Error(`Expected exactly one app with bundle ID ${BUNDLE_ID}; found ${apps.length}.`);
  const app = apps[0];
  const subscriptions = await client.list(`/v1/apps/${app.id}/subscriptions?fields[subscriptions]=productId,name&limit=200`);
  const purchases = await client.list(`/v1/apps/${app.id}/inAppPurchases?fields[inAppPurchases]=productId,referenceName,inAppPurchaseType&limit=200`);
  const monthly = subscriptions.find((item) => attributes(item).productId === PRODUCTS.monthly);
  const yearly = subscriptions.find((item) => attributes(item).productId === PRODUCTS.yearly);
  const founding = purchases.find((item) => attributes(item).productId === PRODUCTS.founding);
  if (!monthly || !yearly || !founding) {
    throw new Error(`Required products missing. Found monthly=${Boolean(monthly)}, yearly=${Boolean(yearly)}, founding=${Boolean(founding)}.`);
  }
  return { app, monthly };
}

async function soldTerritories(client: AscClient, subscriptionId: string): Promise<string[]> {
  const availability = await client.request<JsonApiDocument>(`/v1/subscriptions/${subscriptionId}/subscriptionAvailability`);
  const resource = availability.data as JsonApiResource;
  const territories = await client.list(`/v1/subscriptionAvailabilities/${resource.id}/availableTerritories?limit=200`);
  if (territories.length === 0) throw new Error('The monthly subscription is not available in any territory.');
  return territories.map((territory) => territory.id).sort();
}

async function pointsForOfferPrice(
  client: AscClient,
  subscriptionId: string,
  territoryIds: string[],
  priceFor: (standardPrice: number) => number,
): Promise<Map<string, string>> {
  const current = await client.request<JsonApiDocument>(`/v1/subscriptions/${subscriptionId}/prices?include=territory,subscriptionPricePoint&limit=200`);
  const currentPoints = new Map((current.included ?? []).filter((item) => item.type === 'subscriptionPricePoints').map((item) => [item.id, Number(attributes(item).customerPrice)]));
  const currentByTerritory = new Map<string, number>();
  for (const price of current.data as JsonApiResource[]) {
    const territory = relatedId(price, 'territory');
    const point = relatedId(price, 'subscriptionPricePoint');
    const value = currentPoints.get(point);
    if (territoryIds.includes(territory) && Number.isFinite(value)) currentByTerritory.set(territory, value!);
  }

  const territoryFilter = territoryIds.join(',');
  const points = await client.request<JsonApiDocument>(`/v1/subscriptions/${subscriptionId}/pricePoints?filter[territory]=${encodeURIComponent(territoryFilter)}&include=territory&limit=8000`);
  const candidates = new Map<string, Array<{ id: string; price: number }>>();
  for (const point of points.data as JsonApiResource[]) {
    const territory = relatedId(point, 'territory');
    const price = Number(attributes(point).customerPrice);
    if (Number.isFinite(price)) (candidates.get(territory) ?? candidates.set(territory, []).get(territory)!).push({ id: point.id, price });
  }

  const result = new Map<string, string>();
  for (const territory of territoryIds) {
    const standardPrice = currentByTerritory.get(territory);
    const options = candidates.get(territory) ?? [];
    if (!standardPrice || options.length === 0) throw new Error(`Cannot resolve an offer price for territory ${territory}.`);
    const target = priceFor(standardPrice);
    options.sort((a, b) => Math.abs(a.price - target) - Math.abs(b.price - target) || a.price - b.price);
    result.set(territory, options[0].id);
  }
  return result;
}

function offerPayload(subscriptionId: string, offer: (typeof OFFERS)[number], territoryIds: string[], pricePoints: Map<string, string>) {
  const pricePointFor = (territory: string) => {
    const point = pricePoints.get(territory);
    if (!point) throw new Error(`Missing offer price point for territory ${territory}.`);
    return point;
  };
  const included = territoryIds.map((territory, index) => ({
    type: 'subscriptionOfferCodePrices',
    id: `wheel-price-${index + 1}`,
    relationships: {
      territory: { data: { type: 'territories', id: territory } },
      subscriptionPricePoint: { data: { type: 'subscriptionPricePoints', id: pricePointFor(territory) } },
    },
  }));
  return {
    data: {
      type: 'subscriptionOfferCodes',
      attributes: {
        name: offer.name,
        customerEligibilities: ['NEW'],
        offerEligibility: 'REPLACE_INTRO_OFFERS',
        duration: offer.duration,
        offerMode: offer.offerMode,
        numberOfPeriods: 1,
      },
      relationships: {
        subscription: { data: { type: 'subscriptions', id: subscriptionId } },
        prices: { data: included.map(({ type, id }) => ({ type, id })) },
      },
    },
    included,
  };
}

async function main() {
  if (process.argv.includes('--help') || process.argv.includes('-h')) help();
  const client = new AscClient();
  const { app, monthly } = await appAndProducts(client);
  const existing = await client.list(`/v1/subscriptions/${monthly.id}/offerCodes?fields[subscriptionOfferCodes]=name,customerEligibilities,offerEligibility,duration,offerMode,numberOfPeriods,active&limit=200`);
  const missing = OFFERS.filter((offer) => !existing.some((item) => attributes(item).name === offer.name));
  console.log(`App ${String(attributes(app).name)} (${BUNDLE_ID}); monthly product ${PRODUCTS.monthly}.`);
  for (const offer of OFFERS.filter((offer) => !missing.includes(offer))) console.log(`Exists; skipped: ${offer.name}`);
  if (missing.length === 0) return;

  const territories = await soldTerritories(client, monthly.id);
  for (const offer of missing) {
    // Apple requires a price resource for every offer-code mode. Free trials use the
    // zero-priced subscription point; the paid offer uses the closest point to 50%.
    const pricePoints = await pointsForOfferPrice(
      client,
      monthly.id,
      territories,
      (standard) => (offer.offerMode === 'FREE_TRIAL' ? 0 : standard / 2),
    );
    const payload = offerPayload(monthly.id, offer, territories, pricePoints);
    console.log(`${dryRun ? 'Would create' : 'Creating'}: ${offer.name} (${territories.length} sold territories; ${offer.offerMode}; ${offer.duration}).`);
    if (!dryRun) await client.request('/v1/subscriptionOfferCodes', { method: 'POST', body: JSON.stringify(payload) });
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
