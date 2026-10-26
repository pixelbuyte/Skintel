const { chromium } = require('playwright'); const { spawn } = require('child_process'); const fs = require('fs');
const [,, dir, ad, out] = process.argv;
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  p.on('pageerror', e => console.log('ERR', e.message));
  await p.goto(`file://${dir}/ad.html?ad=${ad}`); await p.evaluate(() => window.ready); await p.waitForTimeout(400);
  const dur = await p.evaluate(() => window.DUR);
  fs.writeFileSync(`${out}.events.json`, JSON.stringify(await p.evaluate(() => window.EVENTS)));
  const ff = spawn('ffmpeg', ['-y','-v','error','-f','image2pipe','-framerate','30','-i','-','-c:v','libx264','-pix_fmt','yuv420p','-crf','18','-preset','medium', `${out}.silent.mp4`]);
  for (let f = 0; f < Math.round(dur * 30); f++) { await p.evaluate(async (t) => { await render(t); }, f / 30); ff.stdin.write(await p.screenshot({ type: 'jpeg', quality: 93 })); }
  ff.stdin.end(); await new Promise(r => ff.on('close', r)); await b.close();
})();
