// Saves every sticker in overlays.html as a transparent 1080×1920 PNG in out/overlays/.
//   CHROME_PATH=... node shoot-overlays.mjs
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const dir = resolve(HERE, 'out', 'overlays');
mkdirSync(dir, { recursive: true });

const browser = await chromium.launch({
  ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}),
  args: ['--force-color-profile=srgb', '--font-render-hinting=none'],
});
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
await page.goto('file://' + resolve(HERE, 'overlays.html'));
const ids = await page.evaluate(() => window.__ids);
for (const id of ids) {
  await page.goto('file://' + resolve(HERE, `overlays.html?o=${id}`));
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: `${dir}/${id}.png`, omitBackground: true });
  console.log('overlay', id);
}
await browser.close();
