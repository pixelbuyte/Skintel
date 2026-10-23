#!/usr/bin/env node
/**
 * Renders App Store screenshots from local HTML at Apple's accepted sizes.
 * Usage: node designs/app-store-screenshots/shoot.mjs
 */
import { chromium } from 'playwright';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const dir = path.dirname(fileURLToPath(import.meta.url));

const shots = [
  {
    html: 'fetch.html',
    // iPhone with Dynamic Island (large): 1290 × 2796
    out: '03-product-recognized.png',
    width: 430,
    height: 932,
    scale: 3,
  },
  {
    html: 'fetch.html',
    // iPhone with Dynamic Island (medium) — currently required in ASC
    out: '03-product-recognized-6.1.png',
    width: 393,
    height: 852,
    scale: 3,
  },
];

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || '/usr/local/bin/google-chrome',
  args: ['--font-render-hinting=none'],
});

try {
  for (const s of shots) {
    const page = await browser.newPage({
      viewport: { width: s.width, height: s.height },
      deviceScaleFactor: s.scale,
    });
    const url = 'file://' + path.join(dir, s.html);
    await page.goto(url, { waitUntil: 'networkidle' });
    await page.evaluate(async () => {
      if (document.fonts?.ready) await document.fonts.ready;
    });
    // Let the remote font CSS settle; mascot PNG is local.
    await page.waitForTimeout(400);
    const out = path.join(dir, s.out);
    await page.locator('#shot').screenshot({ path: out, type: 'png' });
    console.log('wrote', s.out, `${s.width * s.scale}×${s.height * s.scale}`);
    await page.close();
  }
} finally {
  await browser.close();
}
