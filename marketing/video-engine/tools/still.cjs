const { chromium } = require('playwright');
const [,, dir, v, ...ts] = process.argv;
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  p.on('pageerror', e => console.log('ERR', e.message));
  await p.goto(`file://${dir}/ugc2.html?v=${v}`); await p.evaluate(() => window.ready); await p.waitForTimeout(300);
  for (const t of ts) { await p.evaluate(async (t) => { await render(t); }, +t); await p.screenshot({ path: `${dir}/st/${v}-${t}.jpg`, type: 'jpeg', quality: 80 }); }
  await b.close();
})();
