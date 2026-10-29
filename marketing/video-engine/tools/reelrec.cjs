// Records reels.html?r=<n> -> <out>.silent.mp4 + <out>.events.json (sound cues from the reel).
const { chromium } = require('playwright'); const { spawn } = require('child_process'); const fs = require('fs');
const [,, dir, n, out, still] = process.argv;
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  p.on('pageerror', e => console.log('ERR', e.message));
  await p.goto(`file://${dir}/reels.html?r=${n}`); await p.evaluate(() => window.ready); await p.waitForTimeout(300);
  if (still) { for (const t of still.split(',')) { await p.evaluate(async (t) => { await render(t); }, +t); await p.screenshot({ path: `${out}-${t}.jpg`, type: 'jpeg', quality: 80 }); } await b.close(); return; }
  const dur = await p.evaluate(() => window.DUR);
  fs.writeFileSync(`${out}.events.json`, JSON.stringify(await p.evaluate(() => window.EVENTS)));
  const ff = spawn('ffmpeg', ['-y','-v','error','-f','image2pipe','-framerate','30','-i','-','-c:v','libx264','-pix_fmt','yuv420p','-crf','19','-preset','medium', `${out}.silent.mp4`]);
  for (let f = 0; f < Math.round(dur * 30); f++) { await p.evaluate(async (t) => { await render(t); }, f / 30); ff.stdin.write(await p.screenshot({ type: 'jpeg', quality: 92 })); }
  ff.stdin.end(); await new Promise(r => ff.on('close', r)); await b.close();
})();
