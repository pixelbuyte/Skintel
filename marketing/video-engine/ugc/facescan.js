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
  // Light "apothecary" shading (v2): porcelain skin, ink hairlines, clay/rose glows. No black.
  const SH = { darkLow: [214,202,188], darkHigh: [252,248,241], warmLow: [196,120,102], warmHigh: [236,190,176], scan: [163,88,72], L: [-.35,.45,.82] };
  const lerp = (a, b, f) => [a[0]+(b[0]-a[0])*f, a[1]+(b[1]-a[1])*f, a[2]+(b[2]-a[2])*f];
  const BG = '26,24,20', PRI = '163,88,72', HOT = '#A35848';

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
  window.faceCanvas = (w, h, o) => `<canvas width="${w}" height="${h}" data-face='${JSON.stringify(o)}'></canvas>`;
  // Light screens (v2) live in facescan2.js.
})();
