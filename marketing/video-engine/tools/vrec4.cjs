// Records a ugc2 variation and logs on-screen events for the sound pass.
const { chromium } = require('playwright'); const { spawn } = require('child_process'); const fs = require('fs');
const [,, dir, v, out] = process.argv;
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  await p.goto(`file://${dir}/ugc2.html?v=${v}`); await p.evaluate(() => window.ready); await p.waitForTimeout(400);
  const dur = await p.evaluate(() => window.DUR);
  const ff = spawn('ffmpeg', ['-y','-v','error','-f','image2pipe','-framerate','30','-i','-','-c:v','libx264','-pix_fmt','yuv420p','-crf','19','-preset','medium', `${out}.silent.mp4`]);
  const fx = [[0, 'hit', .6], [0.1, 'pop', .5]]; let prev = {};
  for (let f = 0; f < Math.round(dur * 30); f++) {
    const t = f / 30;
    await p.evaluate(async (t) => { await render(t); }, t);
    const s = await p.evaluate(() => ({
      seg: ['hook', 'pov', 'end'].find(id => document.getElementById(id).style.display !== 'none'),
      cap: ($('pcap').firstElementChild || {}).textContent,
      touch: !!document.querySelector('.touch'),
      key: (document.querySelector('.k.hi') || {}).textContent || null,
      layers: document.querySelectorAll('.quad > .scr').length,
    }));
    if (f) {
      if (s.seg !== prev.seg && s.seg === 'pov') fx.push([t - .1, 'whoosh', .8]);
      if (s.seg !== prev.seg && s.seg === 'end') { fx.push([t, 'riser', .4]); fx.push([t, 'chime', .7]); }
      if (s.seg === 'pov' && s.cap !== prev.cap) fx.push([t + .08, 'pop', .45]);
      if (s.touch && !prev.touch) fx.push([t, 'click', .75]);
      if (s.key && s.key !== prev.key) fx.push([t, 'key', .55]);
      if (s.seg === 'pov' && s.layers > (prev.layers || 0) && prev.seg === 'pov') fx.push([t, 'swish', .5]);
    }
    prev = s;
    ff.stdin.write(await p.screenshot({ type: 'jpeg', quality: 92 }));
  }
  fs.writeFileSync(`${out}.events.json`, JSON.stringify({ dur, fx }));
  ff.stdin.end(); await new Promise(r => ff.on('close', r)); await b.close();
})();
