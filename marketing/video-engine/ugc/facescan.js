// Face Scan screens for the videos. The 3D face is a line-for-line JS port of the app's
// FaceMeshView (ios/Skintel/Skintel/Features/FaceScan/FaceMeshView.swift) on the same mesh,
// with the same shading ramps (SKMeshShade), zone falloff (FaceMeshData) and label leaders.
// Screens mirror SweepView.swift and FaceResultView.swift. Needs face_mesh.js + app.js first.
(() => {
  const M = window.FACE_MESH, P = M.v, F = M.f, N = P.length / 3;
  const ANCH = { forehead: 151, nose: 4, left_cheek: 280, right_cheek: 50, chin: 199 };
  const CENT = { forehead: [[151, .42], [108, .3], [337, .3]], nose: [[195, .2], [4, .2]], left_cheek: [[280, .3], [425, .26]],
                 right_cheek: [[50, .3], [205, .26]], chin: [[199, .26], [175, .22]] };
  const W = {};
  for (const z in CENT) { const w = new Float32Array(N); for (let i = 0; i < N; i++) { let b = 0; for (const [c, r] of CENT[z]) {
    const dx = P[i*3]-P[c*3], dy = P[i*3+1]-P[c*3+1], dz = P[i*3+2]-P[c*3+2]; const v = Math.exp(-((dx*dx+dy*dy+dz*dz)/(r*r))*1.6); if (v > b) b = v; } w[i] = b; } W[z] = w; }
  const SH = { darkLow: [24,22,19], darkHigh: [92,84,74], warmLow: [120,60,48], warmHigh: [222,132,110], scan: [244,237,224], L: [-.35,.45,.82],
               lightLow: [206,186,168], lightHigh: [250,244,234] };
  const INK = '26,24,20', CLAY = '122,74,50', MUTED = '107,103,96';
  const lerp = (a, b, f) => [a[0]+(b[0]-a[0])*f, a[1]+(b[1]-a[1])*f, a[2]+(b[2]-a[2])*f];
  const BG = '244,237,224', PRI = '163,88,72', HOT = '#EAD8C8';

  // o: { mode:'result'|'scan', levels:{zone:0..2 (fractional ok)}, labels:[{zone,title,value,side,y,hot}], zoom, yaw, t,
  //      palette:'dark'|'light' (FaceMeshView.Palette) }
  function drawFace(ctx, cw, ch, o) {
    const light = o.palette === 'light';
    const LOW = light ? SH.lightLow : SH.darkLow, HIGH = light ? SH.lightHigh : SH.darkHigh, EDGE = light ? CLAY : BG;
    const t = o.t || 0, swing = o.mode === 'scan' ? .1 : .4;
    const yaw = (o.yaw || 0) + Math.sin(t * .5) * swing, pitch = -.1 + Math.sin(t * .37) * .04;
    const cyw = Math.cos(yaw), syw = Math.sin(yaw), cp = Math.cos(pitch), sp = Math.sin(pitch);
    const scale = Math.min(cw, ch) * (o.zoom || .38), ox = cw / 2, oy = ch / 2 + ch * .01;
    const RX = new Float64Array(N), RY = new Float64Array(N), RZ = new Float64Array(N), X = new Float64Array(N), Y = new Float64Array(N), H = new Float64Array(N);
    const zl = Object.entries(o.levels || {}).filter(([, l]) => l > 0).map(([z, l]) => [W[z], l / 2]);
    for (let i = 0; i < N; i++) {
      const x = P[i*3], y = P[i*3+1], z = P[i*3+2];
      const x1 = x * cyw + z * syw, z1 = -x * syw + z * cyw, y2 = y * cp - z1 * sp, z2 = y * sp + z1 * cp;
      RX[i] = x1; RY[i] = y2; RZ[i] = z2; const k = 4.2 / (4.2 - z2); X[i] = ox + x1 * scale * k; Y[i] = oy - y2 * scale * k;
      let h = 0; for (const [w, l] of zl) { const v = l * w[i]; if (v > h) h = v; } H[i] = h;
    }
    const tris = [];
    for (let k = 0; k + 2 < F.length; k += 3) { const a = F[k], b = F[k+1], c = F[k+2];
      if ((X[b]-X[a])*(Y[c]-Y[a]) - (Y[b]-Y[a])*(X[c]-X[a]) < 0) tris.push(k); }
    tris.sort((p, q) => (RZ[F[p]]+RZ[F[p+1]]+RZ[F[p+2]]) - (RZ[F[q]]+RZ[F[q+1]]+RZ[F[q+2]]));
    const L = SH.L, scanY = 1.15 - ((t * .42) % 1) * 2.5, scanning = o.mode === 'scan';
    ctx.lineWidth = .6;
    for (const k of tris) {
      const a = F[k], b = F[k+1], c = F[k+2];
      const ux = RX[b]-RX[a], uy = RY[b]-RY[a], uz = RZ[b]-RZ[a], vx = RX[c]-RX[a], vy = RY[c]-RY[a], vz = RZ[c]-RZ[a];
      const nx = uy*vz-uz*vy, ny = uz*vx-ux*vz, nz = ux*vy-uy*vx, nl = Math.max(Math.hypot(nx, ny, nz), 1e-9);
      const diff = Math.max(0, (nx*L[0]+ny*L[1]+nz*L[2]) / nl), heat = Math.min(1, ((H[a]+H[b]+H[c]) / 3) * 1.15);
      let rgb = lerp(LOW, HIGH, diff); if (scanning && !light) rgb = rgb.map(v => v * .8);
      rgb = lerp(rgb, lerp(SH.warmLow, SH.warmHigh, diff), heat);
      let edge = .07 + heat * .22;
      if (scanning) { const my = (P[a*3+1]+P[b*3+1]+P[c*3+1]) / 3, d = Math.abs(my - scanY);
        if (d < .12) { const f = 1 - d / .12; rgb = lerp(rgb, light ? SH.warmHigh : SH.scan, f * .55); edge += f * .35; } }
      ctx.beginPath(); ctx.moveTo(X[a], Y[a]); ctx.lineTo(X[b], Y[b]); ctx.lineTo(X[c], Y[c]); ctx.closePath();
      ctx.fillStyle = `rgb(${rgb[0]|0},${rgb[1]|0},${rgb[2]|0})`; ctx.fill();
      ctx.strokeStyle = `rgba(${EDGE},${light ? edge * 1.4 : edge})`; ctx.stroke();
    }
    if (o.mode !== 'scan') {
      ctx.save(); ctx.globalCompositeOperation = light ? 'source-over' : 'lighter';
      for (const z in ANCH) { const l = (o.levels || {})[z] / 2; const i = ANCH[z]; if (!(l > 0) || RZ[i] < -.05) continue;
        const rad = scale * (z === 'forehead' ? .55 : .36), g = ctx.createRadialGradient(X[i], Y[i], 0, X[i], Y[i], rad);
        g.addColorStop(0, `rgba(${PRI},${(light ? .26 : .32) * l})`); g.addColorStop(1, `rgba(${PRI},0)`);
        ctx.fillStyle = g; ctx.beginPath(); ctx.arc(X[i], Y[i], rad, 0, Math.PI * 2); ctx.fill(); }
      ctx.restore();
    } else {
      for (let i = 0; i < N; i += 2) if (RZ[i] >= .05) { const tw = .35 + .65 * Math.abs(Math.sin(t * 2.2 + i * 1.7));
        ctx.fillStyle = `rgba(${light ? PRI : BG},${.55 * tw})`; ctx.fillRect(X[i] - .7, Y[i] - .7, 1.4, 1.4); }
      const sy = oy - scanY * scale, g = ctx.createLinearGradient(0, sy - 18, 0, sy + 18);
      g.addColorStop(0, `rgba(${PRI},0)`); g.addColorStop(.5, `rgba(${PRI},.5)`); g.addColorStop(1, `rgba(${PRI},0)`);
      ctx.fillStyle = g; ctx.fillRect(ox - scale * 1.05, sy - 18, scale * 2.1, 36);
    }
    if (o.mode === 'scan') return;
    ctx.font = "400 11px 'JetBrains Mono'"; ctx.textBaseline = 'middle';
    for (const lb of o.labels || []) {
      const i = ANCH[lb.zone], ax = X[i], ay = Y[i], lead = lb.side === 'leading', lx = lead ? 16 : cw - 16, ly = ch * lb.y;
      const ex = lead ? Math.min(ax - 14, lx + 96) : Math.max(ax + 14, lx - 96), a = lb.alpha == null ? 1 : lb.alpha;
      const TXT = light ? INK : BG;
      ctx.strokeStyle = `rgba(${TXT},${(light ? .3 : .45) * a})`; ctx.lineWidth = .8; ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(ex, ly); ctx.lineTo(lead ? lx + 82 : lx - 82, ly); ctx.stroke();
      ctx.fillStyle = light ? `rgba(${PRI},${a})` : `rgba(${BG},${a})`; ctx.beginPath(); ctx.arc(ax, ay, 2.6, 0, Math.PI * 2); ctx.fill();
      ctx.textAlign = lead ? 'left' : 'right';
      ctx.fillStyle = `rgba(${TXT},${.92 * a})`; ctx.fillText(lb.title, lx, ly - 9);
      ctx.globalAlpha = a; ctx.fillStyle = lb.hot ? (light ? `rgb(${PRI})` : HOT) : (light ? `rgb(${MUTED})` : `rgba(${BG},.62)`); ctx.fillText(lb.value, lx, ly + 7); ctx.globalAlpha = 1;
    }
  }
  // Canvases are emitted as <canvas data-face='json'>; paintFaces() draws them after each innerHTML.
  window.paintFaces = (root) => root.querySelectorAll('canvas[data-face]').forEach(cv => {
    const o = JSON.parse(cv.dataset.face), dpr = 2, w = +cv.getAttribute('width'), h = +cv.getAttribute('height');
    cv.width = w * dpr; cv.height = h * dpr; cv.style.width = w + 'px'; cv.style.height = h + 'px';
    const ctx = cv.getContext('2d'); ctx.scale(dpr, dpr); drawFace(ctx, w, h, o);
  });
  const face = (w, h, o) => `<canvas width="${w}" height="${h}" data-face='${JSON.stringify(o)}'></canvas>`;
  const ink = '#F4EDE0', dim = a => `rgba(244,237,224,${a})`;

  // SweepView (light, 2.0): cream screen = ring light, face in the oval, live hint, check chips.
  // st { step:0..3, prog, t, yaw, done, hint }
  SCREENS.sweep = (st) => {
    const roles = ['Centre', 'Left 45°', 'Right 45°'], step = st.step;
    const title = st.done ? 'Got it' : ['Look straight ahead', 'Slowly turn left', 'Now right'][Math.min(step, 2)];
    const sub = st.done ? 'Reading your skin next' : (st.hint || ['Phone at eye level, face in the oval', 'Keep your phone where it is', 'Keep your phone where it is'][Math.min(step, 2)]);
    const prog = Math.min(st.prog == null ? step : st.prog, 3) / 3;
    const chips = roles.map((r, i) => { const done = i < step, act = i === step && !st.done;
      return `<span style="display:inline-flex;gap:6px;align-items:center;font:${act ? 600 : 400} 13px 'DM Sans';padding:8px 12px;border-radius:99px;color:${done ? '#FFFEFA' : act ? '#8E4538' : '#6B6760'};background:${done ? '#A35848' : act ? 'rgba(163,88,72,.14)' : '#FFFEFA'};border:1px solid ${done || act ? '#A35848' : '#EAE6DF'}">${done ? '✓ ' : ''}${act ? r + ' · now' : r}</span>`; }).join('');
    const ck = (t, ok) => `<span style="font:500 13px 'DM Sans';padding:9px 10px;border-radius:99px;text-align:center;background:${ok ? '#EEF2DD' : '#F5E6DC'};color:${ok ? '#5C7A4F' : '#743C2B'}">${ok ? '✓ ' : '! '}${t}</span>`;
    const hintOn = !!st.hint && !st.done;
    return `<div style="position:absolute;inset:0;background:#F4EDE0;color:#1A1814;font-family:'DM Sans'">${sbar(false)}
      <div style="position:absolute;inset:0;border:14px solid #FFFEFA;border-radius:40px;filter:blur(6px)"></div>
      <div style="position:relative;display:flex;justify-content:space-between;align-items:center;padding:12px 10px 0"><span style="width:44px;text-align:center;font-size:18px">✕</span><span style="font:400 12px 'JetBrains Mono';letter-spacing:1.5px">${st.done ? 'ALL 3 ANGLES' : `ANGLE ${step + 1} OF 3`}</span><span style="width:44px;text-align:center;color:#6B6760">↺</span></div>
      <div style="position:relative;display:flex;gap:12px;align-items:flex-start;padding:10px 26px 0">
        <div style="flex:1"><div style="font:400 32px/1.08 'Instrument Serif'">${title}</div>
          <div style="font:${hintOn ? 600 : 400} 15px 'DM Sans';color:${hintOn ? '#A35848' : '#6B6760'};margin-top:6px">${sub}</div></div>
        <div style="width:84px;height:84px;border-radius:18px;background:#FFFEFA;border:1px solid #EAE6DF;overflow:hidden">${face(84, 84, { mode: 'scan', zoom: .4, yaw: st.yaw || 0, t: st.t, palette: 'light' })}</div></div>
      <div style="position:relative;width:262px;height:344px;margin:22px auto 0">
        <div style="position:absolute;inset:6px;border-radius:50%;overflow:hidden;background:radial-gradient(ellipse at 50% 40%, #E9D9CB, #CDB4A2)">${face(250, 332, { mode: 'scan', zoom: .44, yaw: st.yaw || 0, t: st.t, palette: 'light' })}</div>
        <svg width="262" height="344" style="position:absolute;inset:0"><ellipse cx="131" cy="172" rx="127" ry="168" fill="none" stroke="#EAE6DF" stroke-width="5"/>
        <ellipse cx="131" cy="172" rx="127" ry="168" fill="none" stroke="#A35848" stroke-width="6" stroke-linecap="round" stroke-dasharray="${prog * 940} 940" transform="rotate(-90 131 172)"/></svg></div>
      <div style="position:relative;display:flex;gap:8px;justify-content:center;margin-top:20px">${chips}</div>
      <div style="position:relative;display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:14px 22px 0">${ck(st.dark ? 'Face a window' : 'Good light', !st.dark)}${ck(st.far ? 'Move a little closer' : 'Good distance', !st.far)}${ck(st.still === false ? 'Hold still' : 'Steady', st.still !== false)}${ck('One face', true)}</div>
      <div style="position:absolute;left:50%;bottom:34px;transform:translateX(-50%);width:70px;height:70px;border-radius:50%;border:3px solid #A35848;display:flex;align-items:center;justify-content:center"><i style="width:54px;height:54px;border-radius:50%;background:#A35848;display:block"></i></div></div>`;
  };

  // FaceResultView (light, 2.0): cream hero, the face + mesh, day row, insight + tips card.
  // st { t, day, scans, levels, labels, title, card }
  SCREENS.facemap = (st) => {
    const day = st.day || 1, scans = st.scans || day;
    const btn = n => { const unlock = [1, 3, 5, 7].includes(n), has = n <= scans, on = has && n === day, past = has && !on;
      return `<span style="width:40px;height:40px;border-radius:50%;display:flex;align-items:center;justify-content:center;font:400 12px 'JetBrains Mono';color:${on || past ? '#FFFEFA' : '#6B6760'};background:${on ? '#1A1814' : past ? '#A35848' : '#FFFEFA'};border:${on ? 2 : unlock ? 1.5 : 1}px solid ${on ? '#1A1814' : unlock ? '#A35848' : '#EAE6DF'}">${unlock ? n + '◆' : n}</span>`; };
    return `<div style="position:absolute;inset:0;background:#F4EDE0;color:#1A1814;font-family:'DM Sans'">
      <div style="padding:54px 0 8px">
        <div style="position:absolute;left:0;right:0;top:0">${sbar(false)}</div>
        <div style="display:flex;justify-content:space-between;align-items:center;padding:0 8px"><span style="width:44px;text-align:center;font-size:20px">‹</span><span style="font:400 12px 'JetBrains Mono';letter-spacing:1.5px">FACE SCAN</span><span style="width:44px"></span></div>
        <div style="padding:14px 22px 0"><div style="font:400 11px 'JetBrains Mono';letter-spacing:1.5px;color:#A35848">YOUR SKIN MAP · DAY ${day} OF 7</div>
          <div style="font:400 30px/1.1 'Instrument Serif';margin-top:6px">${st.title || 'Your first map is ready.'}</div></div>
        <div style="margin:10px 14px;border-radius:24px;overflow:hidden;background:linear-gradient(180deg,#EADBCD,#F4EDE0);border:1px solid #EAE6DF">${face(365, 330, { mode: 'result', zoom: .31, levels: st.levels || {}, labels: st.labels || [], t: st.t, palette: 'light' })}</div>
        <div style="padding:0 18px"><div style="position:relative;display:flex;justify-content:space-between"><i style="position:absolute;left:18px;right:18px;top:19px;height:2px;background:#EAE6DF"></i>${[1,2,3,4,5,6,7].map(btn).join('')}</div></div>
      </div>
      <div style="padding:8px 22px 0">${st.card || ''}</div></div>`;
  };
  // FaceQuizView goals question (2.0): st { picked: ['Less shine', ...], th }
  SCREENS.goals = (st) => {
    const opts = ['Less shine', 'Fewer breakouts', 'Fade dark marks', 'Calmer redness', 'Smoother texture', 'Smaller-looking pores', 'More even tone', 'Just know my skin'];
    const on = st.picked || [];
    const chip = o => { const p = on.includes(o);
      return `<span style="display:inline-flex;align-items:center;height:44px;padding:0 16px;border-radius:99px;font:500 15px 'DM Sans';border:1px solid ${p ? '#A35848' : '#EAE6DF'};background:${p ? '#A35848' : '#FFFEFA'};color:${p ? '#FFFEFA' : '#1A1814'}">${o}</span>`; };
    const seg = i => `<i style="flex:1;height:4px;border-radius:2px;background:${i === 0 ? '#A35848' : '#EAE6DF'}"></i>`;
    return `<div style="position:absolute;inset:0;background:#F4EDE0;color:#1A1814;font-family:'DM Sans'">${sbar(false)}
      <div style="display:flex;justify-content:space-between;align-items:center;padding:12px 10px 0"><span style="width:44px;text-align:center;font-size:20px">‹</span><span style="font:400 12px 'JetBrains Mono';letter-spacing:1.5px">QUESTION 1 OF 8</span><span style="font:600 15px 'DM Sans';color:#6B6760;padding-right:8px">Later</span></div>
      <div style="display:flex;gap:4px;padding:8px 22px 0">${[0,1,2,3,4,5,6,7].map(seg).join('')}</div>
      <div style="margin:14px 22px 0;display:flex;align-items:center;gap:10px;background:#FFFEFA;border:1px solid #EAE6DF;border-radius:14px;padding:10px 12px;font-size:13px">
        <i style="width:16px;height:16px;border-radius:50%;border:2px solid #EAE6DF;border-top-color:#A35848;display:block;transform:rotate(${(st.th || 0) * 400}deg)"></i>Reading your skin while you answer</div>
      <div style="font:400 34px/1.06 'Instrument Serif';padding:22px 22px 0">What do you want to improve?</div>
      <div style="font-size:14px;color:#6B6760;padding:8px 22px 0">Pick any. Your tips start with these.</div>
      <div style="display:flex;flex-wrap:wrap;gap:8px;padding:16px 22px 0">${opts.map(chip).join('')}</div>
      <div style="position:absolute;left:22px;right:22px;bottom:84px;height:54px;border-radius:16px;background:#A35848;color:#FFFEFA;font:600 16px 'DM Sans';display:flex;align-items:center;justify-content:center">Next</div>
      <div style="position:absolute;left:0;right:0;bottom:42px;text-align:center;font:600 15px 'DM Sans';color:#6B6760">Not sure, skip this one</div></div>`;
  };
})();
