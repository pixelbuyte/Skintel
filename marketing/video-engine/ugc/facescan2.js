// Face Scan v2 screens for the videos, in the light "apothecary" look the app moved to: porcelain and clay,
// no black. The result is ONE merged view: her own photo (mirrored, like a selfie) with the canonical mesh
// fitted to her real landmarks (face_r3.js), zone glows and spot rings. Needs app.js, face_mesh.js,
// facescan.js and face_r3.js first. The person is AI-generated (label it when posting).
(() => {
  const F = window.FACE_MESH.f, LM = window.FACE_R3, PHOTO = 'photos/r3-bin.jpg';
  const ZC = { forehead: 151, nose: 4, right_cheek: 50, left_cheek: 280, chin: 199 };
  const E = new Set(); const edges = [];
  for (let k = 0; k + 2 < F.length; k += 3) for (const [a, b] of [[F[k], F[k+1]], [F[k+1], F[k+2]], [F[k+2], F[k]]]) {
    const key = a < b ? a * 1000 + b : b * 1000 + a; if (!E.has(key)) { E.add(key); edges.push([a, b]); } }
  const clamp = x => Math.max(0, Math.min(1, x)), ease = x => { x = clamp(x); return 1 - Math.pow(1 - x, 3); };
  // Face box in photo pixels (from the landmarks).
  const xs = LM.p.map(p => p[0] * LM.w), ys = LM.p.map(p => p[1] * LM.h);
  const FB = { x0: Math.min(...xs), x1: Math.max(...xs), y0: Math.min(...ys), y1: Math.max(...ys) };

  // o: { fill: face height as a share of the canvas, cy, pan, levels:{zone:0..2}, labels:[{zone,title,value,alpha}],
  //      rings:[[idx,alpha]], mesh: 0..1, scan: 0..1 (sweep line, top->bottom), t }
  function drawPhoto(ctx, cw, ch, img, o) {
    const fh = FB.y1 - FB.y0, s = (ch * (o.fill || .62)) / fh;
    const fcx = (FB.x0 + FB.x1) / 2, fcy = (FB.y0 + FB.y1) / 2;
    // Mirrored: image x runs right-to-left on screen.
    const ox = cw / 2 + fcx * s + (o.pan || 0), oy = ch * (o.cy || .5) - fcy * s;
    const P = i => [ox - LM.p[i][0] * LM.w * s, oy + LM.p[i][1] * LM.h * s];
    ctx.save(); ctx.translate(ox, oy); ctx.scale(-s, s); ctx.drawImage(img, 0, 0); ctx.restore();
    // Soft porcelain veil so the lines and labels read.
    ctx.fillStyle = 'rgba(255,250,244,.10)'; ctx.fillRect(0, 0, cw, ch);
    // Zone glows (clay, normal blend so a light photo isn't washed out).
    for (const z in ZC) { const l = (o.levels || {})[z] / 2; if (!(l > 0)) continue; const [x, y] = P(ZC[z]);
      const r = fh * s * (z === 'forehead' ? .3 : .2), g = ctx.createRadialGradient(x, y, 0, x, y, r);
      g.addColorStop(0, `rgba(163,88,72,${.42 * l})`); g.addColorStop(1, 'rgba(163,88,72,0)');
      ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill(); }
    // Mesh: porcelain hairlines; with a sweep line, only above it, brighter near it.
    const m = o.mesh == null ? 1 : o.mesh;
    if (m > 0) {
      const sy = o.scan == null ? null : (FB.y0 + (FB.y1 - FB.y0) * (o.scan * 1.2 - .1)) * s + oy;
      ctx.lineWidth = .55;
      for (const [a, b] of edges) { const A = P(a), B = P(b), my = (A[1] + B[1]) / 2;
        let al = .38 * m;
        if (sy != null) { if (my > sy) continue; const d = sy - my; al = (.22 + .55 * Math.max(0, 1 - d / 40)) * m; }
        ctx.strokeStyle = `rgba(255,254,250,${al})`; ctx.beginPath(); ctx.moveTo(A[0], A[1]); ctx.lineTo(B[0], B[1]); ctx.stroke(); }
      if (sy != null && o.scan < 1) { const g = ctx.createLinearGradient(0, sy - 16, 0, sy + 16);
        g.addColorStop(0, 'rgba(255,254,250,0)'); g.addColorStop(.5, 'rgba(255,254,250,.85)'); g.addColorStop(1, 'rgba(255,254,250,0)');
        ctx.fillStyle = g; ctx.fillRect(0, sy - 16, cw, 32); }
    }
    // Spot rings where the read marked something.
    for (const [i, a] of o.rings || []) { if (!(a > 0)) continue; const [x, y] = P(i);
      ctx.strokeStyle = `rgba(255,254,250,${.95 * a})`; ctx.lineWidth = 1.6; ctx.beginPath(); ctx.arc(x, y, 7 + 3 * (1 - a), 0, Math.PI * 2); ctx.stroke();
      ctx.strokeStyle = `rgba(163,88,72,${.9 * a})`; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(x, y, 9.5 + 3 * (1 - a), 0, Math.PI * 2); ctx.stroke(); }
    // Labels: porcelain tags with a leader. The person's right cheek sits on the screen's right (mirrored).
    ctx.textBaseline = 'middle';
    for (const lb of o.labels || []) { const a = lb.alpha == null ? 1 : lb.alpha; if (!(a > 0)) continue;
      const [ax, ay] = P(ZC[lb.zone]), right = lb.side ? lb.side === 'trailing' : ax > cw / 2, ly = ch * lb.y;
      ctx.font = "500 10.5px 'JetBrains Mono'"; const w1 = ctx.measureText(lb.title).width; ctx.font = "500 11px 'JetBrains Mono'";
      const w2 = ctx.measureText(lb.value).width, tw = Math.max(w1, w2) + 16, tx = right ? cw - 10 - tw : 10;
      ctx.globalAlpha = a;
      ctx.strokeStyle = 'rgba(255,254,250,.9)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(right ? tx : tx + tw, ly); ctx.stroke();
      ctx.fillStyle = 'rgba(255,254,250,1)'; ctx.beginPath(); ctx.arc(ax, ay, 2.8, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = 'rgba(255,254,250,.94)'; ctx.beginPath(); ctx.roundRect(tx, ly - 18, tw, 36, 9); ctx.fill();
      ctx.textAlign = 'left'; ctx.font = "500 10.5px 'JetBrains Mono'"; ctx.fillStyle = '#6B6760'; ctx.fillText(lb.title, tx + 8, ly - 7);
      ctx.font = "500 11px 'JetBrains Mono'"; ctx.fillStyle = lb.clear ? '#5C7A4F' : '#A35848'; ctx.fillText(lb.value, tx + 8, ly + 8);
      ctx.globalAlpha = 1; }
  }
  // Canvas text doesn't wait for webfonts; load the label face up front (ugc2.html's ready waits on this).
  window.faceFonts = Promise.all(["500 10.5px 'JetBrains Mono'", "500 11px 'JetBrains Mono'"].map(f => document.fonts.load(f)));
  const prev = window.paintFaces;
  window.paintFaces = (root) => {
    prev && prev(root);
    root.querySelectorAll('canvas[data-photo]').forEach(cv => {
      const o = JSON.parse(cv.dataset.photo), dpr = 2, w = +cv.getAttribute('width'), h = +cv.getAttribute('height');
      cv.width = w * dpr; cv.height = h * dpr; cv.style.width = w + 'px'; cv.style.height = h + 'px';
      const ctx = cv.getContext('2d'); ctx.scale(dpr, dpr); drawPhoto(ctx, w, h, cv.previousElementSibling, o);
    });
  };
  // The hidden <img> before each canvas is what render() waits on before painting.
  const photo = (w, h, o) => `<img src="${PHOTO}" style="display:none"><canvas width="${w}" height="${h}" data-photo='${JSON.stringify(o)}'></canvas>`;
  const mono = (t, c = 'var(--p)') => `<div style="font:500 11px 'JetBrains Mono';letter-spacing:1.5px;color:${c}">${t}</div>`;
  const NEWB = `<span style="font:500 11px 'JetBrains Mono';letter-spacing:1px;background:var(--p);color:var(--cream);border-radius:99px;padding:3px 8px">NEW</span>`;
  const blushHero = 'background:linear-gradient(180deg,#FFFEFA 0%,#F8ECE6 100%);border-bottom:1px solid var(--line)';

  // Today with the Face scan card. st { t, tap }
  SCREENS.facetoday = (st) => `${sbar(false)}<div class="page" style="padding-top:18px">
    <div class="serif" style="font-size:36px;line-height:1">Good morning, Maya</div>
    <div style="margin-top:16px;border-radius:18px;overflow:hidden;display:flex;${blushHero};border:1px solid var(--line);box-shadow:0 1px 3px rgba(26,24,20,.06);transform:scale(${st.tap ? .98 : 1})">
      <div style="flex:1;padding:18px 0 18px 18px;display:flex;flex-direction:column;gap:9px">
        <div style="display:flex;gap:8px;align-items:center">${mono('FACE SCAN')}${NEWB}</div>
        <div class="serif" style="font-size:27px;line-height:1.05">See your skin zone by zone.</div>
        <div style="font-size:14px;color:var(--mu);line-height:1.4">A 15-second head turn, a few questions, then a 7-day check.</div>
        <div style="display:inline-flex;align-self:flex-start;height:36px;padding:0 14px;border-radius:12px;background:var(--p);color:var(--cream);font:600 14px 'DM Sans';align-items:center;margin-top:2px">Scan my face</div>
      </div>
      <div style="width:124px;flex:none">${faceCanvas(124, 196, { mode: 'result', zoom: .42, levels: { right_cheek: 1, left_cheek: 1, nose: 1 }, t: st.t })}</div>
    </div>
    <div class="card" style="margin-top:14px;height:118px">${mono("TODAY'S CHECK-IN", 'var(--mu)')}<div class="serif" style="font-size:24px;margin-top:10px">How did your skin wake up?</div></div>
  </div>${tabbar('today')}`;

  // SweepView, light. st { step, prog, pan, t, done }
  SCREENS.sweep2 = (st) => {
    const roles = ['Front', 'Left', 'Right'], step = st.step;
    const title = st.done ? 'Got all three' : ['Look straight ahead', 'Slowly turn to your left', 'Now slowly to your right'][Math.min(step, 2)];
    const sub = st.done ? 'Next, a few quick questions' : ['Phone at eye level, about an arm away', 'Keep your phone where it is', 'Almost there'][Math.min(step, 2)];
    const prog = Math.min(st.prog == null ? step : st.prog, 3) / 3;
    const chips = roles.map((r, i) => { const done = i < step || st.done, act = i === step && !st.done;
      return `<span style="display:inline-flex;gap:6px;align-items:center;font:500 13px 'DM Sans';padding:8px 13px;border-radius:99px;color:${done ? 'var(--cream)' : act ? 'var(--p)' : 'var(--mu)'};background:${done ? 'var(--p)' : act ? 'rgba(163,88,72,.10)' : 'transparent'};border:1px solid ${done || act ? 'var(--p)' : 'var(--line)'}">${done ? '✓ ' : ''}${r}${act ? ' · now' : ''}</span>`; }).join('');
    const ck = t => `<span style="display:inline-flex;gap:5px;align-items:center"><b style="color:var(--gfg);font-size:12px">✓</b>${t}</span>`;
    return `<div style="position:absolute;inset:0;background:radial-gradient(90% 55% at 50% 44%,#FFFFFF 0%,#FBF6EF 45%,#F4EDE0 100%)">${sbar(false)}
      <div style="display:flex;justify-content:space-between;align-items:center;padding:8px 8px 0"><span style="width:44px;text-align:center;font-size:18px">✕</span>${mono(st.done ? 'ALL 3 ANGLES' : `ANGLE ${step + 1} OF 3`)}<span style="width:44px;text-align:center;color:var(--mu)">↺</span></div>
      <div class="serif" style="font-size:33px;line-height:1.1;text-align:center;padding:12px 28px 0">${title}</div>
      <div style="font-size:15px;color:var(--mu);text-align:center;padding:6px 24px 0">${sub}</div>
      <div style="position:relative;width:286px;height:372px;margin:22px auto 0">
        <div style="position:absolute;inset:-22px;border-radius:50%;background:radial-gradient(closest-side,rgba(255,255,255,0) 82%,rgba(255,255,255,.95) 90%,rgba(255,255,255,0) 100%)"></div>
        <div style="position:absolute;inset:0;border-radius:50%;overflow:hidden;box-shadow:0 0 0 1px var(--line),0 18px 40px rgba(122,74,50,.18)">${photo(286, 372, { fill: .6, cy: .52, pan: st.pan || 0, mesh: 1, scan: st.scan, t: st.t })}</div>
        <svg width="286" height="372" style="position:absolute;inset:0;overflow:visible"><ellipse cx="143" cy="186" rx="150" ry="194" fill="none" stroke="var(--line)" stroke-width="5"/>
        <ellipse cx="143" cy="186" rx="150" ry="194" fill="none" stroke="#A35848" stroke-width="5" stroke-linecap="round" stroke-dasharray="${prog * 1080} 1080" transform="rotate(-90 143 186)"/></svg></div>
      <div style="display:flex;gap:8px;justify-content:center;margin-top:30px">${chips}</div>
      <div style="display:flex;gap:16px;justify-content:center;margin-top:16px;font-size:13px;color:var(--mu)">${ck('Even light')}${ck('Arm away')}${ck('One face')}</div>
      <div style="position:absolute;left:36px;right:36px;bottom:28px;text-align:center;font-size:12px;color:var(--mu)">Mirrored, like a selfie. Photos are read, then deleted.</div></div>`;
  };

  // Questions with the read running underneath. st { picked:[i], ready, t, hot }
  const GOALS = ['Less shine', 'Fewer breakouts', 'Fade marks', 'Calmer redness', 'Smoother texture', 'Smaller-looking pores', 'More glow', 'A simpler routine', 'Just curious'];
  SCREENS.quiz2 = (st) => {
    const dots = [0, 1, 2].map(i => `<i style="width:5px;height:5px;border-radius:50%;background:var(--p);opacity:${.3 + .7 * Math.abs(Math.sin(st.t * 4 + i))}"></i>`).join('');
    const pill = st.ready
      ? `<span style="display:inline-flex;gap:7px;align-items:center;background:var(--gbg);color:var(--gfg);border-radius:99px;padding:7px 12px;font:600 13px 'DM Sans'">✓ Your map is ready</span>`
      : `<span style="display:inline-flex;gap:7px;align-items:center;background:rgba(163,88,72,.08);color:var(--p);border-radius:99px;padding:7px 12px;font:600 13px 'DM Sans'"><span style="display:inline-flex;gap:3px">${dots}</span>Reading your photos while you answer</span>`;
    const chips = GOALS.map((g, i) => { const on = (st.picked || []).includes(i);
      return `<span style="display:inline-flex;align-items:center;gap:6px;height:42px;padding:0 15px;border-radius:99px;font:500 15px 'DM Sans';background:${on ? 'var(--p)' : 'var(--cream)'};color:${on ? 'var(--cream)' : 'var(--ink)'};border:1px solid ${on ? 'var(--p)' : 'var(--line)'};transform:scale(${st.hot === i ? .95 : 1})">${on ? '✓ ' : ''}${g}</span>`; }).join('');
    return `${sbar(false)}<div style="display:flex;justify-content:space-between;align-items:center;padding:6px 8px 0"><span style="width:44px;text-align:center;font-size:20px">‹</span>${mono('QUESTION 1 OF 6', 'var(--mu)')}<span style="width:44px"></span></div>
      <div style="height:4px;margin:10px 22px 0;border-radius:2px;background:var(--line)"><div style="width:17%;height:100%;border-radius:2px;background:var(--p)"></div></div>
      <div class="page" style="padding-top:16px">${pill}
        <div style="font-size:13px;color:var(--mu);margin-top:16px">From your profile: <b style="color:var(--ink);font-weight:600">Combination skin</b> · <span style="color:var(--p);font-weight:600">Edit</span></div>
        <div class="serif" style="font-size:31px;line-height:1.08;margin-top:10px">What do you want to improve?</div>
        <div style="font-size:14px;color:var(--mu);margin-top:6px">Pick all that apply.</div>
        <div style="display:flex;flex-wrap:wrap;gap:9px;margin-top:18px">${chips}</div></div>
      <div style="position:absolute;left:22px;right:22px;bottom:44px;display:flex;flex-direction:column;gap:10px">
        <div class="btn" style="opacity:${(st.picked || []).length ? 1 : .45}">Next</div>
        <div style="display:flex;gap:10px"><div style="flex:1;height:44px;border-radius:12px;border:1px solid var(--line);display:flex;align-items:center;justify-content:center;font:500 15px 'DM Sans';color:var(--mu)">Not sure</div><div style="flex:1;height:44px;border-radius:12px;border:1px solid var(--line);display:flex;align-items:center;justify-content:center;font:500 15px 'DM Sans';color:var(--mu)">Skip</div></div></div>`;
  };

  // Result: the merged photo + mesh hero, then the zones and the AI's suggestions. st { t, levels, labels, rings, scroll, title }
  SCREENS.facemap2 = (st) => {
    const zones = [['Forehead', 'Looks clear and even.', 'Clear', true], ['Nose & T-zone', 'A little shine down the centre.', 'Shine · Some', false],
      ['Right cheek', 'A few small red marks near the jaw.', 'Redness · Some', false], ['Left cheek', 'Some redness beside the nose.', 'Redness · Some', false], ['Chin', 'Looks clear.', 'Clear', true]];
    const bars = c => `<span style="display:inline-flex;gap:3px">${[0, 1].map(i => `<i style="width:14px;height:6px;border-radius:3px;background:${!c && i === 0 ? 'var(--p)' : 'var(--line)'}"></i>`).join('')}</span>`;
    const rows = zones.map(([n, note, w, c], i) => `<div style="display:flex;align-items:center;gap:10px;padding:11px 0;${i ? 'border-top:1px solid var(--line)' : ''}">
      <div style="flex:1"><div style="font:600 15px 'DM Sans'">${n}</div><div style="font-size:12.5px;color:var(--mu);margin-top:2px">${note}</div></div>${bars(c)}
      <div style="font:500 13px 'DM Sans';min-width:96px;text-align:right;color:${c ? 'var(--gfg)' : 'var(--ink)'}">${c ? '✓ ' : ''}${w}</div></div>`).join('');
    const tips = [['Calm it, don\'t scrub it', 'There\'s some redness on both cheeks. A gentle gel cleanser and a niacinamide serum help keep it calmer.'],
      ['SPF 30+ every morning', 'It keeps red marks from darkening while they fade.']];
    const tipCard = `<div class="card" style="margin-top:12px">${mono('WHAT SKINSTEL SUGGESTS')}${tips.map(([t, w]) => `<div style="margin-top:12px;display:flex;gap:10px"><span style="width:26px;height:26px;border-radius:50%;background:#EAD8C8;color:#7A4A32;display:flex;align-items:center;justify-content:center;font-size:13px;flex:none">✦</span><div><div style="font:600 15px 'DM Sans'">${t}</div><div style="font-size:13.5px;color:var(--mu);line-height:1.4;margin-top:2px">${w}</div></div></div>`).join('')}
      <div style="display:flex;gap:8px;margin-top:14px"><span style="height:34px;padding:0 12px;border-radius:99px;background:rgba(163,88,72,.08);color:var(--p);font:600 13px 'DM Sans';display:inline-flex;align-items:center">Ask: how do I calm the redness?</span></div></div>`;
    const dayBtn = n => { const on = n === 1, unlock = [1, 3, 5, 7].includes(n);
      return `<span style="width:36px;height:36px;border-radius:50%;display:flex;align-items:center;justify-content:center;font:500 12px 'JetBrains Mono';color:${on ? 'var(--cream)' : 'var(--mu)'};background:${on ? 'var(--p)' : 'var(--cream)'};border:1px solid ${on ? 'var(--p)' : unlock ? 'rgba(163,88,72,.5)' : 'var(--line)'}">${n}${unlock && !on ? '◆' : ''}</span>`; };
    return `<div style="position:absolute;inset:0;background:var(--bg)"><div style="transform:translateY(${-(st.scroll || 0)}px)">
      <div style="${blushHero};border-radius:0 0 28px 28px;padding-bottom:16px">${sbar(false)}
        <div style="display:flex;justify-content:space-between;align-items:center;padding:0 8px"><span style="width:44px;text-align:center;font-size:20px">‹</span>${mono('FACE SCAN', 'var(--ink)')}<span style="width:44px"></span></div>
        <div style="padding:10px 22px 0">${mono('YOUR SKIN MAP · DAY 1 OF 7')}<div class="serif" style="font-size:29px;line-height:1.08;margin-top:6px">${st.title || 'Some redness on your cheeks. The rest looks clear.'}</div></div>
        <div style="display:flex;justify-content:space-between;align-items:center;padding:12px 22px 0"><div style="display:flex;background:var(--chip);border-radius:99px;padding:3px"><span style="height:28px;padding:0 14px;border-radius:99px;background:var(--cream);box-shadow:0 1px 3px rgba(26,24,20,.12);font:600 13px 'DM Sans';display:flex;align-items:center">Photo</span><span style="height:28px;padding:0 14px;font:600 13px 'DM Sans';display:flex;align-items:center;color:var(--mu)">3D</span></div><span style="font-size:12px;color:var(--mu)">Mirrored, like a selfie</span></div>
        <div style="margin:12px 16px 0;border-radius:20px;overflow:hidden;box-shadow:0 0 0 1px var(--line)">${photo(361, 318, { fill: .68, cy: .53, mesh: st.mesh == null ? 1 : st.mesh, levels: st.levels || {}, labels: st.labels || [], rings: st.rings || [], t: st.t })}</div>
        <div style="display:flex;justify-content:space-between;padding:14px 22px 0">${[1, 2, 3, 4, 5, 6, 7].map(dayBtn).join('')}</div>
      </div>
      <div class="page" style="padding-top:14px"><div class="card" style="padding:4px 16px">${rows}</div>${tipCard}</div>
    </div></div>`;
  };

  // Ask with the Face scan tag in the composer. st: as askScreen, plus tag:true, mentionFace:true
  SCREENS.askface = (st) => {
    const chip = `<span style="display:inline-flex;align-items:center;gap:5px;height:26px;padding:0 10px;border-radius:99px;background:rgba(163,88,72,.10);color:var(--p);font:600 13px 'DM Sans';margin-right:6px;vertical-align:1px">◉ Face scan</span>`;
    const base = SCREENS.ask({ ...st, mention: null, input: st.tag && !st.q ? chip + (st.input || '') : st.input });
    const panel = st.mentionFace ? `<div style="position:absolute;left:16px;right:16px;bottom:208px;z-index:30;background:var(--cream);border:1px solid var(--line);border-radius:18px;box-shadow:0 8px 24px rgba(26,24,20,.10);overflow:hidden">
      <div class="lbl" style="padding:10px 14px 4px">Your skin</div>
      <div style="display:flex;gap:10px;align-items:center;padding:9px 14px;background:${st.mHot ? 'rgba(163,88,72,.08)' : 'transparent'}"><span style="width:34px;height:34px;border-radius:10px;background:#EAD8C8;color:#7A4A32;display:flex;align-items:center;justify-content:center">◉</span><div><div style="font:600 15px 'DM Sans'">Face scan</div><div style="font-size:12.5px;color:var(--mu)">Day 1 map · today</div></div></div>
      <div class="lbl" style="padding:8px 14px 4px">Your shelf</div><div style="padding:6px 14px 12px;font-size:15px;color:var(--mu)">CeraVe Foaming Facial Cleanser</div></div>` : '';
    const sentTag = st.q ? `<div style="position:absolute;right:22px;top:${st.qTop || 128}px;z-index:5">${chip}</div>` : '';
    return base + panel + sentTag;
  };
})();
