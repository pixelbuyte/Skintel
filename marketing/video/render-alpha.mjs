// Renders a transparent composition (plane.html) to:
//   out/<name>-f<N>.mov   ProRes 4444 with alpha (CapCut desktop, Premiere, Final Cut)
//   out/<name>-f<N>.webm  VP9 with alpha (web, some mobile editors)
//   out/<name>-f<N>-preview.mp4  over a sample background, to look at
// and the flat flyer for printing: out/<name>-f<N>-print.png
//   CHROME_PATH=... node render-alpha.mjs plane 1
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { mkdirSync, rmSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const [, , NAME = 'plane', F = '1', FPS_ARG] = process.argv;
const FPS = Number(FPS_ARG || 30);
const tag = `${NAME}-f${F}`;
const frames = resolve(HERE, `frames_${tag}`);
const out = resolve(HERE, 'out');
rmSync(frames, { recursive: true, force: true });
mkdirSync(frames, { recursive: true });
mkdirSync(out, { recursive: true });

const browser = await chromium.launch({
  ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}),
  args: ['--force-color-profile=srgb', '--font-render-hinting=none'],
});
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
await page.goto('file://' + resolve(HERE, `${NAME}.html?f=${F}`));
await page.evaluate(() => document.fonts.ready);
await page.waitForTimeout(300);
const total = Math.round((await page.evaluate(() => window.__duration)) * FPS);
for (let i = 0; i < total; i++) {
  await page.evaluate(t => window.__seek(t), i / FPS);
  await page.screenshot({ path: `${frames}/f_${String(i).padStart(5, '0')}.png`, omitBackground: true });
}
await page.goto('file://' + resolve(HERE, `${NAME}.html?f=${F}&print=1`));
await page.evaluate(() => document.fonts.ready);
await page.screenshot({ path: `${out}/${tag}-print.png` });
await browser.close();

const input = ['-y', '-v', 'error', '-framerate', String(FPS), '-i', `${frames}/f_%05d.png`];
execFileSync('ffmpeg', [...input, '-c:v', 'prores_ks', '-profile:v', '4444', '-pix_fmt', 'yuva444p10le', `${out}/${tag}.mov`], { stdio: 'inherit' });
execFileSync('ffmpeg', [...input, '-c:v', 'libvpx-vp9', '-pix_fmt', 'yuva420p', '-b:v', '0', '-crf', '28', '-auto-alt-ref', '0', `${out}/${tag}.webm`], { stdio: 'inherit' });
execFileSync('ffmpeg', ['-y', '-v', 'error', '-f', 'lavfi', '-i', `color=c=0x8FA3A0:s=1080x1920:r=${FPS}`,
  '-framerate', String(FPS), '-i', `${frames}/f_%05d.png`,
  '-filter_complex', '[0][1]overlay=shortest=1', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', `${out}/${tag}-preview.mp4`], { stdio: 'inherit' });
rmSync(frames, { recursive: true, force: true });
console.log('→', `${out}/${tag}.{mov,webm}`, `${tag}-preview.mp4`, `${tag}-print.png`);
