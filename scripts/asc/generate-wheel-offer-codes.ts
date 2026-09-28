import { AscClient, type JsonApiResource } from './asc-client.ts';

const PRODUCT_ID = 'com.skintel.app.pro.monthly';
const OFFER_NAMES = new Set(['Wheel - 3 days free', 'Wheel - 7 days free', 'Wheel - 50% off first month']);

function usage(): never {
  console.log('Usage: node --experimental-strip-types scripts/asc/generate-wheel-offer-codes.ts --offer "Wheel - 3 days free" --count 500 --expires YYYY-MM-DD [--dry-run]');
  process.exit(0);
}

function value(flag: string): string | undefined {
  const index = process.argv.indexOf(flag);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function assertFutureDate(date: string): void {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || Number.isNaN(Date.parse(`${date}T00:00:00Z`))) throw new Error('--expires must be a YYYY-MM-DD date.');
  const expiration = Date.parse(`${date}T00:00:00Z`);
  if (expiration <= Date.now()) throw new Error('--expires must be in the future.');
  const sixMonthsFromNow = new Date();
  sixMonthsFromNow.setUTCMonth(sixMonthsFromNow.getUTCMonth() + 6);
  if (expiration > sixMonthsFromNow.getTime()) throw new Error('Apple permits one-time-use codes to expire no more than six months after generation.');
}

async function main() {
  if (process.argv.includes('--help') || process.argv.includes('-h')) usage();
  const offerName = value('--offer');
  const count = Number(value('--count'));
  const expires = value('--expires');
  const dryRun = process.argv.includes('--dry-run');
  if (!offerName || !OFFER_NAMES.has(offerName) || !Number.isInteger(count) || count < 500 || count > 25_000 || !expires) usage();
  assertFutureDate(expires!);

  const client = new AscClient();
  const apps = await client.list('/v1/apps?filter[bundleId]=com.skintel.app&fields[apps]=bundleId&limit=1');
  if (apps.length !== 1) throw new Error('Expected exactly one app with bundle ID com.skintel.app.');
  const subscriptions = await client.list(`/v1/apps/${apps[0].id}/subscriptions?fields[subscriptions]=productId&limit=200`);
  const monthly = subscriptions.find((item: JsonApiResource) => item.attributes?.productId === PRODUCT_ID);
  if (!monthly) throw new Error(`Missing ${PRODUCT_ID}.`);
  const offers = await client.list(`/v1/subscriptions/${monthly.id}/offerCodes?fields[subscriptionOfferCodes]=name&limit=200`);
  const offer = offers.find((item) => item.attributes?.name === offerName);
  if (!offer) throw new Error(`Offer not found: ${offerName}. Run wheel-offers.ts first.`);

  console.log(`${dryRun ? 'Would create' : 'Creating'} ${count} one-time-use codes for ${offerName}, expiring ${expires}.`);
  if (!dryRun) {
    await client.request('/v1/subscriptionOfferCodeOneTimeUseCodes', {
      method: 'POST',
      body: JSON.stringify({
        data: {
          type: 'subscriptionOfferCodeOneTimeUseCodes',
          attributes: { numberOfCodes: count, expirationDate: expires },
          relationships: { offerCode: { data: { type: 'subscriptionOfferCodes', id: offer.id } } },
        },
      }),
    });
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
