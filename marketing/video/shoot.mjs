// Screenshot each static artboard in a page to its own PNG.
//
//   node shoot.mjs ads            → out/ads/ad1.png … adN.png
//   node shoot.mjs ads .ad 1200 628
//
// Artboards are matched by CSS selector (default `.ad`) and named by their id.

import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const [, , NAME = 'ads', SELECTOR = '.ad'] = process.argv;

const outDir = resolve(HERE, 'out', NAME);
mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({
  // Honour CHROME_PATH when set (preinstalled browser in CI or a sandbox);
  // otherwise let Playwright resolve the Chromium it installed itself.
  ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}),
  args: ['--force-color-profile=srgb', '--disable-lcd-text', '--font-render-hinting=none'],
});
const page = await browser.newPage({ viewport: { width: 1400, height: 1400 }, deviceScaleFactor: 1 });

await page.goto('file://' + resolve(HERE, `${NAME}.html`));
await page.evaluate(() => document.fonts.ready);
await page.waitForTimeout(500); // let images decode

const boards = await page.locator(SELECTOR).all();
console.log(`${NAME}: ${boards.length} artboards`);

for (const board of boards) {
  const id = (await board.getAttribute('id')) || `board${boards.indexOf(board)}`;
  const box = await board.boundingBox();
  await board.screenshot({ path: `${outDir}/${id}.png` });
  console.log(`  ${id}.png  ${Math.round(box.width)}x${Math.round(box.height)}`);
}

await browser.close();
console.log('→', outDir);
