// Face Scan Pro v2 screens for the "Introducing Face Scan" demo, drawn from the approved design
// (Skinstel Face Scan Pro artifact: Sweep, Quiz, Main, Ask) and the shipped SwiftUI
// (SweepView, FaceQuizView, FaceResultView, RecommendView). Needs app.js, face_mesh.js, facescan.js.
(() => {
  const face = (w, h, o) => `<canvas width="${w}" height="${h}" data-face='${JSON.stringify(o)}'></canvas>`;
  const mono = (sz, c, ls = 1.5) => `font:500 ${sz}px 'JetBrains Mono';letter-spacing:${ls}px;color:${c}`;
  const NEW = `<span style="${mono(10, '#FFFEFA', 1)};background:#A35848;border-radius:99px;padding:2px 7px">NEW</span>`;
  const check = (c = 'currentColor', s = 13, w = 3) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l5 5L20 7"/></svg>`;
  const spark = (c = 'currentColor', s = 13) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="${c}"><path d="M12 3l1.8 4.7 4.7 1.8-4.7 1.8L12 16l-1.8-4.7-4.7-1.8 4.7-1.8z"/></svg>`;
  const chev = (d, c = '#1A1814') => `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="${d}"/></svg>`;
  const BASE = `position:absolute;inset:0;background:#F4EDE0;color:#1A1814;font-family:'DM Sans';overflow:hidden`;

  // SweepView: stadium portal with the cream ring-light halo, Front / Left / Right chips, live checks.
  // st { step 0..3, prog 0..3, yaw, t, done, hint, far }
  SCREENS.sweep2 = (st) => {
    const step = Math.min(st.step, 3);
    const copy = [['ANGLE 1 OF 3', 'Look straight ahead', 'Phone at eye level, about 35 cm away'],
                  ['ANGLE 2 OF 3', 'Slowly turn to your left', 'Keep your phone where it is'],
                  ['ANGLE 3 OF 3', 'Now slowly to your right', 'Almost there'],
                  ['ALL 3 ANGLES', 'Got it. Reading your skin', 'Questions next, while it reads']][st.done ? 3 : step];
    const pct = Math.round(Math.min(st.prog, 3) / 3 * 100);
    const chips = ['Front', 'Left', 'Right'].map((n, i) => {
      const done = i < step || st.done, act = i === step && !st.done;
      return `<span style="display:inline-flex;align-items:center;gap:6px;height:34px;padding:0 12px 0 9px;border-radius:99px;font:600 13px 'DM Sans';
        background:${done ? '#EEF2DD' : act ? '#FFFEFA' : 'transparent'};border:${done ? '1px solid #EEF2DD' : act ? '1.5px solid #A35848' : '1px solid #EAE6DF'};color:${done ? '#5C7A4F' : act ? '#1A1814' : '#6B6760'}">
        ${done ? check('#5C7A4F', 11, 3.4) : act ? '<i style="width:9px;height:9px;border-radius:50%;background:#A35848;display:block"></i>' : '<i style="width:9px;height:9px;border-radius:50%;border:1.5px solid #6B6760;display:block;box-sizing:border-box"></i>'}${act ? n + ' · now' : n}</span>`;
    }).join('');
    const ck = (t, ok) => `<span style="display:flex;align-items:center;gap:5px;font:400 13px 'DM Sans'"><i style="width:15px;height:15px;border-radius:50%;background:${ok ? '#5C7A4F' : '#743C2B'};display:flex;align-items:center;justify-content:center;color:#fff;font:700 10px 'DM Sans';font-style:normal">${ok ? check('#fff', 9, 4) : '!'}</i>${t}</span>`;
    const hintOn = !!st.hint && !st.done;
    const W = 264, H = 345;
    return `<div style="${BASE}">${sbar(false)}
      <div style="display:flex;justify-content:space-between;align-items:center;padding:0 10px"><span style="width:44px;text-align:center;font-size:18px">✕</span><span style="${mono(12, '#A35848')}">${copy[0]}</span><span style="width:44px;text-align:center;color:#6B6760;font-size:18px">↺</span></div>
      <div style="text-align:center;font:400 32px/1.06 'Instrument Serif';padding:8px 26px 0">${copy[1]}</div>
      <div style="text-align:center;font:${hintOn ? 600 : 400} 15px 'DM Sans';color:${hintOn ? '#A35848' : '#6B6760'};margin-top:6px">${hintOn ? st.hint : copy[2]}</div>
      <div style="position:relative;width:${W}px;height:${H}px;margin:44px auto 0">
        <div style="position:absolute;left:-24px;top:-24px;right:-24px;bottom:-24px;border-radius:200px;background:#FFFEFA;box-shadow:0 0 42px 24px rgba(255,254,250,.95),0 20px 40px rgba(26,24,20,.08)"></div>
        <div style="position:absolute;left:-11px;top:-11px;right:-11px;bottom:-11px;border-radius:190px;border:1px solid #EAE6DF"></div>
        <div style="position:absolute;inset:0;border-radius:${W / 2}px;overflow:hidden;background:#EAD8C8">${face(W, H, { mode: 'scan', zoom: .42, yaw: st.yaw || 0, t: st.t, palette: 'light' })}</div>
        <svg width="${W + 22}" height="${H + 22}" style="position:absolute;left:-11px;top:-11px;overflow:visible"><rect x="0" y="0" width="${W + 22}" height="${H + 22}" rx="${(W + 22) / 2}" fill="none" stroke="#A35848" stroke-width="4" stroke-linecap="round" pathLength="100" stroke-dasharray="${pct} ${101 - pct}"/></svg>
        <span style="position:absolute;left:50%;top:14px;transform:translateX(-50%);${mono(10, '#7A4A32', 1)};background:rgba(255,254,250,.88);border-radius:99px;padding:4px 10px;white-space:nowrap">CAMERA · MIRRORED</span>
      </div>
      <div style="display:flex;gap:8px;justify-content:center;margin-top:44px">${chips}</div>
      <div style="display:flex;gap:14px;justify-content:center;margin-top:16px">${ck(st.far ? 'Move closer' : '35 cm away', !st.far)}${ck('Even light', true)}${ck('One face', true)}</div>
      <div style="position:absolute;bottom:40px;left:40px;right:40px;text-align:center;font-size:12px;line-height:1.4;color:#6B6760">Your 3D face shape stays on this phone. Only the photos are read, then deleted.</div></div>`;
  };

  // FaceQuizView, question 1 of 7. st { picked:[], read:bool, th }
  SCREENS.quiz2 = (st) => {
    const opts = ['Less shine', 'Fewer breakouts', 'Fade marks', 'Calmer redness', 'Smoother texture', 'Smaller-looking pores', 'More glow', 'A simpler routine', 'Just curious'];
    const on = st.picked || [];
    const chip = o => { const p = on.includes(o);
      return `<span style="display:inline-flex;align-items:center;gap:6px;height:42px;padding:0 15px;border-radius:99px;font:500 15px 'DM Sans';border:1px solid ${p ? '#A35848' : '#EAE6DF'};background:${p ? '#A35848' : '#FFFEFA'};color:${p ? '#FFFEFA' : '#1A1814'}">${p ? check('#FFFEFA', 12) : ''}${o}</span>`; };
    const seg = i => `<i style="flex:1;height:4px;border-radius:2px;background:${i === 0 ? '#A35848' : '#EAE6DF'};display:block"></i>`;
    const pill = st.read
      ? `<i style="width:18px;height:18px;border-radius:50%;background:#EEF2DD;display:flex;align-items:center;justify-content:center">${check('#5C7A4F', 10, 3.6)}</i>Photos read · your map is ready`
      : `<i style="width:18px;height:18px;border-radius:50%;border:2px solid #EAD8C8;border-top-color:#A35848;display:block;box-sizing:border-box;transform:rotate(${(st.th || 0) * 400}deg)"></i>Reading your photos while you answer…`;
    return `<div style="${BASE}">${sbar(false)}
      <div style="display:flex;justify-content:space-between;align-items:center;padding:0 10px"><span style="width:44px;display:flex;justify-content:center">${chev('M15 18l-6-6 6-6')}</span><span style="${mono(12, '#1A1814')}">QUESTION 1 OF 7</span><span style="width:44px"></span></div>
      <div style="display:flex;justify-content:center;padding:4px 0 10px"><span style="display:flex;align-items:center;gap:8px;height:32px;padding:0 14px 0 10px;border-radius:99px;background:#FFFEFA;border:1px solid #EAE6DF;font-size:13px">${pill}</span></div>
      <div style="display:flex;gap:4px;padding:0 22px">${[0,1,2,3,4,5,6].map(seg).join('')}</div>
      <div style="margin:14px 22px 0;display:flex;align-items:center;gap:10px;background:#FFFEFA;border:1px solid #EAE6DF;border-radius:14px;padding:0 12px;height:48px;font-size:14px">
        <i style="width:28px;height:28px;border-radius:9px;background:rgba(163,88,72,.08);display:flex;align-items:center;justify-content:center;color:#A35848;font-style:normal">💧</i>
        <span style="flex:1"><span style="color:#6B6760">From your profile:</span> <b style="font-weight:600">Combination skin</b></span><span style="color:#A35848;font-weight:600">Edit</span></div>
      <div style="font:400 32px/1.05 'Instrument Serif';padding:16px 22px 0">What do you want to improve?</div>
      <div style="font-size:14px;line-height:1.4;color:#6B6760;padding:8px 22px 0">Pick all that apply. Skinstel suggests what to try for each one.</div>
      <div style="display:flex;flex-wrap:wrap;gap:8px;padding:14px 22px 0">${opts.map(chip).join('')}</div>
      <div style="position:absolute;left:22px;right:22px;bottom:104px;display:flex;gap:8px">
        <span style="flex:1;height:46px;border:1px solid #EAE6DF;border-radius:14px;display:flex;align-items:center;justify-content:center;font-weight:600">Skip</span>
        <span style="flex:1;height:46px;border:1px solid #EAE6DF;border-radius:14px;display:flex;align-items:center;justify-content:center;font-weight:600">Not sure</span></div>
      <div style="position:absolute;left:22px;right:22px;bottom:38px;height:54px;border-radius:14px;background:#A35848;color:#FFFEFA;font:600 17px 'DM Sans';display:flex;align-items:center;justify-content:center;opacity:${on.length ? 1 : .4}">Next</div></div>`;
  };

  // The design's sample read.
  const ZONES = [
    { k: 'forehead', name: 'Forehead', note: 'A little shine across the middle. No bumps or marks.', sc: [0, 1, 0, 0, 0], top: 'Shine' },
    { k: 'nose', name: 'Nose & T-zone', note: 'A small flat brown mark on the side of the nose, and some shine.', sc: [0, 1, 0, 1, 0], top: 'Flat mark' },
    { k: 'left_cheek', name: 'Left cheek', note: 'A faint pink patch close to the nose.', sc: [1, 0, 0, 0, 0], top: 'Redness' },
    { k: 'right_cheek', name: 'Right cheek', note: 'Even tone. Nothing stands out.', sc: [0, 0, 0, 0, 0], top: '' },
    { k: 'chin', name: 'Chin', note: 'Two small raised bumps on the left side of the chin.', sc: [0, 0, 2, 0, 1], top: 'Raised blemish' },
  ];
  const WORDS = ['None', 'Some', 'Noticeable'], METRICS = ['Redness', 'Shine', 'Raised blemishes', 'Flat marks', 'Texture'];
  const TONE = [['#EEF2DD', '#5C7A4F'], ['#F5E6DC', '#743C2B'], ['#EAD8C8', '#7A4A32']];
  window.DEMO_LEVELS = Object.fromEntries(ZONES.map(z => [z.k, Math.max(...z.sc)]));

  // FaceResultView. st { view:'photo'|'3d', scroll, open, k (glow 0..1), t, yaw, hot:'3d'|'ask'|null }
  SCREENS.main2 = (st) => {
    const photo = st.view !== '3d', k = st.k == null ? 1 : st.k;
    const levels = Object.fromEntries(Object.entries(window.DEMO_LEVELS).map(([z, l]) => [z, l * k]));
    const seg = (label, on) => `<span style="min-width:74px;height:40px;padding:0 14px;border-radius:99px;display:flex;align-items:center;justify-content:center;font:600 14px 'DM Sans';background:${on ? '#FFFEFA' : 'transparent'};color:${on ? '#1A1814' : '#6B6760'};box-shadow:${on ? '0 1px 2px rgba(26,24,20,.08),0 1px 3px rgba(26,24,20,.08)' : 'none'}">${label}</span>`;
    const zone = (z, i) => {
      const max = Math.max(...z.sc), open = st.open === z.k, [bg, fg] = TONE[max];
      const top = max === 0 ? 'Clear' : `${z.top} · ${WORDS[max]}`;
      const glyph = max === 0 ? check(fg, 12, 3) : `<svg width="16" height="12" viewBox="0 0 16 12"><circle cx="4" cy="6" r="3" fill="${fg}"/><circle cx="12" cy="6" r="2.4" fill="${max === 2 ? fg : 'none'}" stroke="${fg}" stroke-width="1.2"/></svg>`;
      const bars = open ? `<div style="padding:0 0 12px;display:flex;flex-direction:column;gap:8px">${METRICS.map((m, j) => { const v = z.sc[j];
        return `<div style="display:flex;align-items:center;gap:10px;font-size:13px"><span style="width:116px">${m}</span><span style="flex:1;display:flex;gap:3px"><i style="flex:1;height:8px;border-radius:3px;background:${v >= 1 ? '#A35848' : '#EAE6DF'};display:block"></i><i style="flex:1;height:8px;border-radius:3px;background:${v >= 2 ? '#A35848' : '#EAE6DF'};display:block"></i></span><span style="width:80px;text-align:right;font-weight:600;color:${v ? '#1A1814' : '#6B6760'}">${WORDS[v]}</span></div>`; }).join('')}</div>` : '';
      return `<div style="border-bottom:${i === ZONES.length - 1 ? 0 : '1px solid #EAE6DF'};background:${st.hotZone === z.k ? 'rgba(163,88,72,.05)' : 'transparent'}">
        <div style="display:flex;gap:10px;padding:12px 0;align-items:flex-start"><div style="flex:1;display:flex;flex-direction:column;gap:6px">
          <div style="display:flex;justify-content:space-between;align-items:center"><span style="font:600 15px 'DM Sans'">${z.name}</span>
          <span style="display:flex;align-items:center;gap:6px;height:28px;padding:0 10px 0 8px;border-radius:99px;background:${bg};color:${fg};font:600 13px 'DM Sans'">${glyph}${top}</span></div>
          <span style="font-size:13px;line-height:1.4;color:#6B6760">${z.note}</span></div>
          <span style="margin-top:4px">${chev(open ? 'M6 15l6-6 6 6' : 'M6 9l6 6 6-6', '#6B6760')}</span></div>${bars}</div>`;
    };
    const tip = (n, t, w) => `<div style="display:flex;gap:12px;align-items:flex-start;padding-top:12px;border-top:1px solid #EAE6DF"><span style="width:28px;height:28px;flex:none;border-radius:50%;background:#EAD8C8;color:#7A4A32;${mono(12, '#7A4A32', 0)};display:flex;align-items:center;justify-content:center">${n}</span><span style="display:flex;flex-direction:column;gap:3px"><span style="font:600 15px 'DM Sans'">${t}</span><span style="font-size:13px;line-height:1.4;color:#6B6760">${w}</span></span></div>`;
    const goal = (g, h, q, hot) => `<div style="display:flex;flex-direction:column;gap:8px;padding:12px 0;border-top:1px solid #EAE6DF"><span style="display:flex;justify-content:space-between;align-items:baseline"><span style="font:600 15px 'DM Sans'">${g}</span><span style="font-size:12px;color:#6B6760">${h}</span></span>
      <span style="align-self:flex-start;height:42px;display:flex;align-items:center;gap:7px;padding:0 14px;border-radius:99px;border:1px solid ${hot ? '#A35848' : '#EAE6DF'};background:${hot ? 'rgba(163,88,72,.14)' : 'rgba(163,88,72,.06)'};color:#8E4538;font:600 14px 'DM Sans'">${spark('#8E4538')}${q}</span></div>`;
    const map = photo
      ? face(393, 300, { mode: 'result', zoom: .33, levels, t: st.t, yaw: st.yaw || 0, palette: 'photo' })
      : face(393, 300, { mode: 'result', zoom: .33, levels, t: st.t, yaw: st.yaw || 0, palette: 'paper' });
    const CARD = `background:#FFFEFA;border:1px solid #EAE6DF;border-radius:16px;box-shadow:0 1px 2px rgba(26,24,20,.04),0 1px 3px rgba(26,24,20,.06)`;
    return `<div style="${BASE}"><div style="position:absolute;left:0;right:0;top:0;transform:translateY(${-(st.scroll || 0)}px)">
      <div style="background:#FFFEFA;border-bottom:1px solid #EAE6DF;border-radius:0 0 28px 28px;overflow:hidden"><div style="background:rgba(163,88,72,.06);padding-bottom:14px">
        ${sbar(false)}
        <div style="display:flex;justify-content:space-between;align-items:center;padding:0 10px"><span style="width:44px;display:flex;justify-content:center">${chev('M15 18l-6-6 6-6')}</span><span style="display:flex;align-items:center;gap:8px"><span style="${mono(12, '#1A1814')}">FACE SCAN</span>${NEW}</span><span style="width:44px"></span></div>
        <div style="padding:10px 22px 0;display:flex;flex-direction:column;gap:4px"><span style="${mono(11, '#A35848')}">YOUR SKIN MAP · DAY 1 OF 7</span>
          <span style="font:400 32px/1.02 'Instrument Serif'">Your first map is ready.</span>
          <span style="font-size:14px;line-height:1.4;color:#6B6760">Some shine on your T-zone, two small bumps on your chin, one flat mark by your nose.</span></div>
        <div style="display:flex;justify-content:space-between;align-items:center;padding:12px 22px 0"><span style="display:flex;padding:3px;border-radius:99px;background:#EFEAE2;outline:${st.hot === '3d' ? '2px solid rgba(163,88,72,.4)' : 'none'}">${seg('Photo', photo)}${seg('3D', !photo)}</span>
          <span style="font-size:12px;color:#6B6760">⇆ Mirrored, like a selfie</span></div>
        <div style="position:relative;margin-top:4px">${map}
          <span style="position:absolute;left:22px;top:8px;${mono(10, '#7A4A32', 1)};background:#FFFEFA;border:1px solid #EAE6DF;border-radius:99px;padding:4px 10px">${photo ? 'YOUR PHOTO · ON THIS PHONE' : '3D · DRAG TO TURN'}</span>
          <span style="position:absolute;right:22px;top:12px;${mono(10, '#6B6760', 1)}">YOUR RIGHT ›</span></div>
        <div style="display:flex;align-items:center;gap:6px;padding:2px 22px 0;font-size:12px;color:#6B6760"><i style="width:14px;height:14px;border-radius:50%;background:rgba(163,88,72,.22);display:block"></i>Glow means more showing</div>
      </div></div>
      <div style="padding:18px 22px 30px;display:flex;flex-direction:column;gap:14px">
        <div style="display:flex;justify-content:space-between;align-items:baseline"><span style="${mono(11, '#6B6760', 1.6)}">ZONE BY ZONE</span><span style="font-size:12px;color:#6B6760">Tap a zone for all five reads</span></div>
        <div style="${CARD};padding:2px 16px">${ZONES.map(zone).join('')}</div>
        <div style="${CARD};padding:16px;display:flex;flex-direction:column;gap:12px">
          <div style="display:flex;justify-content:space-between"><span style="${mono(11, '#A35848', 1.6)}">WHAT SKINSTEL SUGGESTS</span><span style="font-size:12px;color:#6B6760">From this scan</span></div>
          ${tip(1, "Blot, don't scrub, the T-zone", 'Shine sits on your forehead and nose while your cheeks read clear. Blotting at midday takes it down without drying the rest.')}
          ${tip(2, 'Leave the chin bumps alone', 'Two small raised bumps on one side. Picking tends to leave marks; keep the rest of your routine as it is.')}
          ${tip(3, 'Sunscreen for the flat mark', "Flat brown marks look more even when daily sun can't darken them.")}
          <span style="font-size:12px;color:#6B6760">Ideas to try, not a treatment plan.</span></div>
        <div style="${CARD};padding:12px 16px 4px">
          <div style="display:flex;justify-content:space-between;align-items:center;height:32px"><span style="${mono(11, '#6B6760', 1.6)}">FOR YOUR GOALS</span><span style="font:600 14px 'DM Sans';color:#A35848">Edit</span></div>
          ${goal('Less shine', 'T-zone · Some', 'How do I get less shine?', st.hot === 'ask')}
          ${goal('Fade marks', 'Nose · one flat mark', 'How do I fade the mark by my nose?')}
          ${goal('A simpler routine', '7 steps on your shelf', 'Which steps can I drop?')}</div>
      </div></div></div>`;
  };

  // Ask with the face scan tagged. st { answer (html so far), card 0..1, thinking }
  SCREENS.ask2 = (st) => {
    const thumb = face(70, 86, { mode: 'result', zoom: .42, levels: window.DEMO_LEVELS, t: 0, palette: 'photo' });
    return `<div style="${BASE}">${sbar(false)}
      <div style="display:flex;justify-content:space-between;align-items:center;padding:0 16px;height:44px"><span style="color:#A35848;font-size:16px">Close</span><span style="font:600 16px 'DM Sans'">Ask Skinstel</span><span style="width:44px"></span></div>
      <div style="padding:12px 20px;display:flex;flex-direction:column;gap:16px">
        <div style="display:flex;flex-direction:column;align-items:flex-end;gap:6px">
          <div style="display:flex;align-items:center;gap:6px">${NEW}<span style="display:flex;align-items:center;gap:6px;height:30px;padding:0 10px 0 4px;border-radius:99px;background:#FFFEFA;border:1px solid #EAE6DF"><span style="width:22px;height:22px;border-radius:6px;background:#EAD8C8;display:flex;align-items:center;justify-content:center;color:#7A4A32;font-size:12px">◉</span><span style="font:600 13px 'DM Sans'">Face scan · Day 1 map</span></span></div>
          <div style="max-width:280px;background:#A35848;color:#FFFEFA;border-radius:20px;padding:11px 16px;font-size:16px;line-height:1.4">How do I get less shine?</div></div>
        <div style="display:flex;gap:12px;align-items:flex-start">
          <span style="width:28px;height:28px;border-radius:50%;background:#A35848;color:#FFFEFA;display:flex;align-items:center;justify-content:center;flex:none">${spark('#FFFEFA', 14)}</span>
          <div style="flex:1;display:flex;flex-direction:column;gap:12px;font-size:15.5px;line-height:1.45">
            ${st.thinking ? '<span style="color:#6B6760">● ● ●</span>' : `<div>${st.answer || ''}</div>`}
            <div style="opacity:${st.card || 0};transform:translateY(${(1 - (st.card || 0)) * 10}px);display:flex;gap:12px;align-items:center;background:#FFFEFA;border:1px solid #EAE6DF;border-radius:16px;padding:10px 14px 10px 10px;box-shadow:0 1px 2px rgba(26,24,20,.04),0 1px 3px rgba(26,24,20,.06)">
              <span style="width:70px;height:86px;border-radius:12px;overflow:hidden;background:rgba(163,88,72,.06);flex:none">${thumb}</span>
              <span style="display:flex;flex-direction:column;gap:4px"><span style="display:flex;align-items:center;gap:6px"><span style="${mono(10, '#A35848', 1)}">FROM YOUR FACE SCAN</span>${NEW}</span>
                <span style="font:600 15px 'DM Sans'">Nose &amp; T-zone · Shine</span><span style="font-size:13px;color:#6B6760">Some on Day 1</span><span style="font:600 13px 'DM Sans';color:#A35848">Open your map ›</span></span></div>
            <span style="opacity:${st.card || 0};font-size:13px;color:#6B6760">A cosmetic read of a photo, not a diagnosis.</span>
          </div></div></div></div>`;
  };
})();
