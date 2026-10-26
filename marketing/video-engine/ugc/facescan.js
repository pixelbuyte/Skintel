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
  const SH = { darkLow: [24,22,19], darkHigh: [92,84,74], warmLow: [120,60,48], warmHigh: [222,132,110], scan: [244,237,224], L: [-.35,.45,.82] };
  const lerp = (a, b, f) => [a[0]+(b[0]-a[0])*f, a[1]+(b[1]-a[1])*f, a[2]+(b[2]-a[2])*f];
  const BG = '244,237,224', PRI = '163,88,72', HOT = '#EAD8C8';

  // o: { mode:'result'|'scan', levels:{zone:0..2 (fractional ok)}, labels:[{zone,title,value,side,y,hot}], zoom, yaw, t }
  function drawFace(ctx, cw, ch, o) {
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
      let rgb = lerp(SH.darkLow, SH.darkHigh, diff); if (scanning) rgb = rgb.map(v => v * .8);
      rgb = lerp(rgb, lerp(SH.warmLow, SH.warmHigh, diff), heat);
      let edge = .07 + heat * .22;
      if (scanning) { const my = (P[a*3+1]+P[b*3+1]+P[c*3+1]) / 3, d = Math.abs(my - scanY);
        if (d < .12) { const f = 1 - d / .12; rgb = lerp(rgb, SH.scan, f * .55); edge += f * .35; } }
      ctx.beginPath(); ctx.moveTo(X[a], Y[a]); ctx.lineTo(X[b], Y[b]); ctx.lineTo(X[c], Y[c]); ctx.closePath();
      ctx.fillStyle = `rgb(${rgb[0]|0},${rgb[1]|0},${rgb[2]|0})`; ctx.fill();
      ctx.strokeStyle = `rgba(${BG},${edge})`; ctx.stroke();
    }
    if (o.mode !== 'scan') {
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (const z in ANCH) { const l = (o.levels || {})[z] / 2; const i = ANCH[z]; if (!(l > 0) || RZ[i] < -.05) continue;
        const rad = scale * (z === 'forehead' ? .55 : .36), g = ctx.createRadialGradient(X[i], Y[i], 0, X[i], Y[i], rad);
        g.addColorStop(0, `rgba(${PRI},${.32 * l})`); g.addColorStop(1, `rgba(${PRI},0)`);
        ctx.fillStyle = g; ctx.beginPath(); ctx.arc(X[i], Y[i], rad, 0, Math.PI * 2); ctx.fill(); }
      ctx.restore();
    } else {
      for (let i = 0; i < N; i += 2) if (RZ[i] >= .05) { const tw = .35 + .65 * Math.abs(Math.sin(t * 2.2 + i * 1.7));
        ctx.fillStyle = `rgba(${BG},${.55 * tw})`; ctx.fillRect(X[i] - .7, Y[i] - .7, 1.4, 1.4); }
      const sy = oy - scanY * scale, g = ctx.createLinearGradient(0, sy - 18, 0, sy + 18);
      g.addColorStop(0, `rgba(${PRI},0)`); g.addColorStop(.5, `rgba(${PRI},.5)`); g.addColorStop(1, `rgba(${PRI},0)`);
      ctx.fillStyle = g; ctx.fillRect(ox - scale * 1.05, sy - 18, scale * 2.1, 36);
    }
    if (o.mode === 'scan') return;
    ctx.font = "400 11px 'JetBrains Mono'"; ctx.textBaseline = 'middle';
    for (const lb of o.labels || []) {
      const i = ANCH[lb.zone], ax = X[i], ay = Y[i], lead = lb.side === 'leading', lx = lead ? 16 : cw - 16, ly = ch * lb.y;
      const ex = lead ? Math.min(ax - 14, lx + 96) : Math.max(ax + 14, lx - 96), a = lb.alpha == null ? 1 : lb.alpha;
      ctx.strokeStyle = `rgba(${BG},${.45 * a})`; ctx.lineWidth = .8; ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(ex, ly); ctx.lineTo(lead ? lx + 82 : lx - 82, ly); ctx.stroke();
      ctx.fillStyle = `rgba(${BG},${a})`; ctx.beginPath(); ctx.arc(ax, ay, 2.6, 0, Math.PI * 2); ctx.fill();
      ctx.textAlign = lead ? 'left' : 'right';
      ctx.fillStyle = `rgba(${BG},${.92 * a})`; ctx.fillText(lb.title, lx, ly - 9);
      ctx.globalAlpha = a; ctx.fillStyle = lb.hot ? HOT : `rgba(${BG},.62)`; ctx.fillText(lb.value, lx, ly + 7); ctx.globalAlpha = 1;
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

  // SweepView: st { step:0..3, t, yaw, done }
  SCREENS.sweep = (st) => {
    const roles = ['Centre', 'Left 45°', 'Right 45°'], step = st.step;
    const title = st.done ? 'Got it. Reading your skin' : ['Look straight ahead', 'Slowly turn to your left', 'Now slowly to your right'][Math.min(step, 2)];
    const sub = st.done ? 'About 10 seconds' : ['Phone at eye level, about 35 cm away', 'Keep your phone where it is', 'Almost there'][Math.min(step, 2)];
    const prog = Math.min(st.prog == null ? step : st.prog, 3) / 3, C = 2 * Math.PI * 130;
    const chips = roles.map((r, i) => { const done = i < step, act = i === step && !st.done;
      return `<span style="display:inline-flex;gap:6px;align-items:center;font:400 13px 'DM Sans';padding:8px 12px;border-radius:99px;color:${done || act ? '#FFFEFA' : dim(.72)};background:${done ? '#A35848' : act ? 'rgba(163,88,72,.25)' : 'transparent'};border:1px solid ${done || act ? '#A35848' : dim(.3)}">${done ? '✓ ' : ''}${act ? r + ' · now' : r}</span>`; }).join('');
    const ck = (t, ok) => `<span style="display:inline-flex;gap:6px;align-items:center"><b style="color:${ok ? '#EEF2DD' : dim(.5)};font-size:11px">${ok ? '✓' : '◌'}</b>${t}</span>`;
    return `<div style="position:absolute;inset:0;background:#0B0A08;color:${ink};font-family:'DM Sans'">${sbar(true)}
      <div style="display:flex;justify-content:space-between;align-items:center;padding:12px 8px 0"><span style="width:44px;text-align:center;font-size:18px">✕</span><span style="font:400 12px 'JetBrains Mono';letter-spacing:1.5px">${st.done ? 'ALL 3 ANGLES' : `ANGLE ${step + 1} OF 3`}</span><span style="width:44px;text-align:center;color:${dim(.7)}">↺</span></div>
      <div style="font:400 34px/1.1 'Instrument Serif';text-align:center;padding:14px 30px 0">${title}</div>
      <div style="font-size:15px;color:${dim(.72)};text-align:center;padding:8px 24px 0">${sub}</div>
      <div style="position:relative;width:300px;height:380px;margin:24px auto 0">${face(300, 380, { mode: 'scan', zoom: .4, yaw: st.yaw || 0, t: st.t })}
        <svg width="300" height="380" style="position:absolute;inset:0"><ellipse cx="150" cy="190" rx="136" ry="176" fill="none" stroke="${dim(.12)}" stroke-width="6"/>
        <ellipse cx="150" cy="190" rx="136" ry="176" fill="none" stroke="#A35848" stroke-width="6" stroke-linecap="round" stroke-dasharray="${prog * 990} 990" transform="rotate(-90 150 190)"/></svg></div>
      <div style="display:flex;gap:8px;justify-content:center;margin-top:24px">${chips}</div>
      <div style="display:flex;gap:16px;justify-content:center;margin-top:20px;font-size:13px;color:${dim(.8)}">${ck('Even light', true)}${ck('35 cm away', true)}${ck('One face', true)}</div>
      <div style="position:absolute;left:40px;right:40px;bottom:30px;text-align:center;font-size:12px;color:${dim(.6)}">The 3D face is a model, not a scan of you. Day 1 close-ups stay on this phone until Day 7, then are deleted.</div></div>`;
  };

  // FaceResultView hero + first card: st { t, day, levels, labels, title }
  SCREENS.facemap = (st) => {
    const day = st.day || 1, scans = st.scans || day;
    const btn = n => { const unlock = [1, 3, 5, 7].includes(n), has = n <= scans, on = has && n === day, past = has && !on;
      return `<span style="width:40px;height:40px;border-radius:50%;display:flex;align-items:center;justify-content:center;font:400 12px 'JetBrains Mono';color:${on ? '#0B0A08' : past ? '#FFFEFA' : dim(.75)};background:${on ? ink : past ? '#A35848' : '#0B0A08'};border:${on ? 2 : unlock ? 1.5 : 1}px solid ${on ? ink : unlock ? '#A35848' : dim(.25)}">${unlock ? n + '◆' : n}</span>`; };
    return `<div style="position:absolute;inset:0;background:#F4EDE0;font-family:'DM Sans'">
      <div style="background:#0B0A08;color:${ink};border-radius:0 0 28px 28px;padding:54px 0 22px">${''}
        <div style="position:absolute;left:0;right:0;top:0">${sbar(true)}</div>
        <div style="display:flex;justify-content:space-between;align-items:center;padding:0 8px"><span style="width:44px;text-align:center;font-size:18px">‹</span><span style="font:400 12px 'JetBrains Mono';letter-spacing:1.5px">FACE SCAN</span><span style="width:44px"></span></div>
        <div style="padding:14px 22px 0"><div style="font:400 11px 'JetBrains Mono';letter-spacing:1.5px;color:${HOT}">YOUR SKIN MAP · DAY ${day} OF 7</div>
          <div style="font:400 30px/1.1 'Instrument Serif';margin-top:6px">${st.title || 'Your first map is ready.'}</div></div>
        ${face(393, 330, { mode: 'result', zoom: .31, levels: st.levels || {}, labels: st.labels || [], t: st.t })}
        <div style="padding:0 18px"><div style="position:relative;display:flex;justify-content:space-between"><i style="position:absolute;left:18px;right:18px;top:19px;height:2px;background:${dim(.14)}"></i>${[1,2,3,4,5,6,7].map(btn).join('')}</div>
          <div style="display:flex;justify-content:space-between;margin-top:10px;font-size:12px;color:${dim(.62)}"><span>Tap a day · drag the face to turn it</span><span style="font:400 11px 'JetBrains Mono';color:${HOT}">◆ = unlock day</span></div></div>
      </div>
      <div style="padding:16px 22px 0">${st.card || ''}</div></div>`;
  };
})();
