// Reaction-hook videos (HOOKS.md): render each demo body once (f-*.html?mode=body) and each
// 2.2 s hook once (hook.html?h=N), then cut hook + body together with ffmpeg. Also writes the kit
// for founder-filmed reactions: the hook lines as transparent PNGs and the bodies on their own.
//   CHROME_PATH=... node build-hooks.mjs            (all)
//   CHROME_PATH=... node build-hooks.mjs 2 7        (only hooks 2 and 7)
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, copyFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = resolve(HERE, 'out');
const KIT = resolve(OUT, 'hook-kit');
mkdirSync(KIT, { recursive: true });

// Hook number → the demo that pays it off. Numbers match hook.html and HOOKS.md.
const PAIRS = {
  1: 'triggers', 2: 'conflicts', 3: 'scan', 4: 'scan', 5: 'triggers', 6: 'scan',
  7: 'ask-when', 8: 'triggers', 9: 'conflicts', 10: 'ask-tag', 11: 'conflicts', 12: 'scan',
};
const only = process.argv.slice(2).map(Number).filter(Boolean);
const hooks = Object.keys(PAIRS).map(Number).filter(h => !only.length || only.includes(h));
const pad = n => String(n).padStart(2, '0');

function render(name, query, suffix) {
  execFileSync('node', [resolve(HERE, 'render.mjs'), name, '30', '1', suffix], {
    stdio: ['ignore', 'ignore', 'inherit'], env: { ...process.env, QUERY: query, FMT: 'jpeg' },
  });
  return resolve(OUT, `skintel-${name}${suffix}.mp4`);
}

// 1. Bodies, once each (skipped when already rendered).
const bodies = {};
for (const b of new Set(hooks.map(h => PAIRS[h]))) {
  const file = resolve(OUT, `skintel-f-${b}-body.mp4`);
  bodies[b] = existsSync(file) ? file : render(`f-${b}`, 'mode=body', '-body');
  copyFileSync(bodies[b], resolve(KIT, `body-${b}.mp4`));
  console.log('body', b);
}

// 2. Hooks + 3. cut: hook, then the body from 0.5 s (its first beat lands right away).
for (const h of hooks) {
  const clip = render('hook', `h=${h}`, `-${pad(h)}`);
  const final = resolve(OUT, `hook-${pad(h)}-${PAIRS[h]}.mp4`);
  execFileSync('ffmpeg', ['-y', '-v', 'error', '-i', clip, '-ss', '0.5', '-i', bodies[PAIRS[h]],
    '-filter_complex', '[0:v][1:v]concat=n=2:v=1:a=0[v]', '-map', '[v]',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', final]);
  console.log('→', final);
}

// 4. Kit text overlays: the hook line alone, transparent, same position as in the videos.
const browser = await chromium.launch({ ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
for (const h of hooks) {
  await page.goto('file://' + resolve(HERE, `hook.html?h=${h}&kit=1`));
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: resolve(KIT, `text-${pad(h)}.png`), omitBackground: true });
}
await browser.close();
console.log('kit →', KIT);
