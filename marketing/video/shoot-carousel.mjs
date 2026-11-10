// Saves every slide in carousel.html as a 1080×1920 PNG in out/carousel/ (slide-1.png …).
//   CHROME_PATH=... node shoot-carousel.mjs     (stock/build_reveal.py runs it after saving the app screens)
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const dir = resolve(HERE, 'out', 'carousel');
mkdirSync(dir, { recursive: true });

const browser = await chromium.launch({
  ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}),
  args: ['--force-color-profile=srgb', '--font-render-hinting=none'],
});
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
await page.goto('file://' + resolve(HERE, 'carousel.html'));
const ids = await page.evaluate(() => window.__ids);
for (const id of ids) {
  await page.goto('file://' + resolve(HERE, `carousel.html?s=${id}`));
  await page.evaluate(() => document.fonts.ready);
  await page.evaluate(() => Promise.all([...document.images].map(i => i.complete ? 0 : new Promise(r => { i.onload = i.onerror = r; }))));
  await page.screenshot({ path: `${dir}/slide-${id}.png` });
  console.log('slide', id);
}
await browser.close();
