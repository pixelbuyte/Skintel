import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const [, , NAME, ...times] = process.argv;
const dir = resolve(HERE, `probe_${NAME}`);
mkdirSync(dir, { recursive: true });

const browser = await chromium.launch({
  // Honour CHROME_PATH when set (preinstalled browser in CI or a sandbox);
  // otherwise let Playwright resolve the Chromium it installed itself.
  ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}),
  args: ['--force-color-profile=srgb', '--disable-lcd-text', '--font-render-hinting=none'],
});
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
await page.goto('file://' + resolve(HERE, `${NAME}.html`));
await page.evaluate(() => document.fonts.ready);
await page.waitForTimeout(400);

for (const ts of times) {
  await page.evaluate(t => window.__seek(t), Number(ts));
  await page.locator('#stage').screenshot({ path: `${dir}/t${ts}.png` });
  console.log('probe', ts);
}
await browser.close();
