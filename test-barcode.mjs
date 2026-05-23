// Test barcode lookup against production
const SUPABASE_URL = 'https://fgttlowgvoonedqglyle.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY;
const EMAIL = 'rrswat00@gmail.com';
const PASSWORD = 'TestPass_skintel_2026!';

async function main() {
  if (!SUPABASE_ANON) throw new Error('SUPABASE_ANON_KEY env required');
  // 1. Get JWT
  const auth = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON },
    body: JSON.stringify({ email: EMAIL, password: PASSWORD }),
  });
  const authJson = await auth.json();
  if (!authJson.access_token) {
    console.error('Auth failed:', authJson);
    process.exit(1);
  }
  const token = authJson.access_token;
  console.log('Got JWT (len)', token.length);

  // 1b. Hit vercel share URL to get bypass cookie
  const shareUrl = 'https://skintel-six.vercel.app/?_vercel_share=yoyMlPI2grvJjh1QKXd57hLWjZDrzNBT';
  const shareResp = await fetch(shareUrl, { redirect: 'manual' });
  console.log('Share URL status:', shareResp.status);
  const setCookies = shareResp.headers.getSetCookie?.() ?? [shareResp.headers.get('set-cookie')].filter(Boolean);
  const cookieHeader = setCookies.map((c) => c.split(';')[0]).join('; ');
  console.log('Cookies:', cookieHeader.slice(0, 200));

  // 2. Test barcodes
  const upcs = ['3337875597197', '0072140017769', '3600523971084'];
  for (const upc of upcs) {
    console.log(`\n--- UPC ${upc} ---`);
    const r = await fetch(`https://skintel-six.vercel.app/api/lookup?mode=barcode&upc=${upc}`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
        Cookie: cookieHeader,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36',
        Accept: 'application/json',
      },
    });
    console.log('Status:', r.status);
    const ct = r.headers.get('content-type') || '';
    if (ct.includes('application/json')) {
      const j = await r.json();
      console.log('Source:', j.source);
      console.log('Brand:', j.brand);
      console.log('Product:', j.productName);
      console.log('Ingredients len:', (j.ingredients || '').length);
      console.log('Ingredients sample:', (j.ingredients || '').slice(0, 200));
    } else {
      const t = await r.text();
      console.log('Non-JSON:', t.slice(0, 300));
    }
  }
}
main().catch((e) => { console.error(e); process.exit(1); });
