import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { mkdirSync, rmSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const [, , NAME, FPS_ARG, SCALE_ARG, SUFFIX_ARG] = process.argv;
if (!NAME) {
  console.error('usage: node render.mjs <v1|v2|v3> [fps] [timeScale] [outSuffix]');
  process.exit(1);
}

const FPS = Number(FPS_ARG || 30);
// Stretch (>1) or compress (<1) the whole timeline without touching the scene files:
// output frame at time t renders the composition's state at t / SCALE. Used to fit
// the picture to a voiceover rather than speeding the voiceover up to fit the picture.
const SCALE = Number(SCALE_ARG || 1);
const SUFFIX = SUFFIX_ARG || '';
const W = 1080, H = 1920;
const frameDir = resolve(HERE, `frames_${NAME}${SUFFIX}`);
const outDir = resolve(HERE, 'out');

if (existsSync(frameDir)) rmSync(frameDir, { recursive: true, force: true });
mkdirSync(frameDir, { recursive: true });
mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({
  // Honour CHROME_PATH when set (preinstalled browser in CI or a sandbox);
  // otherwise let Playwright resolve the Chromium it installed itself.
  ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}),
  args: ['--force-color-profile=srgb', '--disable-lcd-text', '--font-render-hinting=none'],
});
const page = await browser.newPage({
  viewport: { width: W, height: H },
  deviceScaleFactor: 1,
});

await page.goto('file://' + resolve(HERE, `${NAME}.html`));
await page.evaluate(() => document.fonts.ready);
await page.waitForTimeout(400); // let images decode

const baseDuration = await page.evaluate(() => window.__duration);
const duration = baseDuration * SCALE;
const total = Math.round(duration * FPS);
console.log(
  `${NAME}: ${baseDuration}s × ${SCALE} = ${duration.toFixed(2)}s @ ${FPS}fps = ${total} frames`,
);

const stage = page.locator('#stage');
const t0 = Date.now();

for (let i = 0; i < total; i++) {
  const t = i / FPS / SCALE;
  await page.evaluate(tt => window.__seek(tt), t);
  await stage.screenshot({
    path: `${frameDir}/f_${String(i).padStart(5, '0')}.png`,
    animations: 'disabled',
  });
  if (i % 60 === 0 || i === total - 1) {
    const pct = (((i + 1) / total) * 100).toFixed(0);
    const el = ((Date.now() - t0) / 1000).toFixed(0);
    console.log(`  ${pct}%  (${i + 1}/${total})  ${el}s`);
  }
}
await browser.close();

const mp4 = resolve(outDir, `skintel-${NAME}${SUFFIX}.mp4`);
execFileSync('ffmpeg', [
  '-y', '-v', 'error',
  '-framerate', String(FPS),
  '-i', `${frameDir}/f_%05d.png`,
  '-c:v', 'libx264',
  '-preset', 'slow',
  '-crf', '17',
  '-pix_fmt', 'yuv420p',
  '-profile:v', 'high',
  '-movflags', '+faststart',
  '-r', String(FPS),
  mp4,
], { stdio: 'inherit' });

rmSync(frameDir, { recursive: true, force: true });
console.log('→', mp4);
