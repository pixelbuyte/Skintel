// Kiku-style Skinstel reels: 3 s reaction hook (no talking, big outlined text) -> HARD CUT -> full-screen
// app recording with beat overlays. Plan: marketing/reels/skinstel-reels-week1.md.
// The demo half here is the engine's rebuild of the real screens (RoutineView, scanner -> VerdictView,
// Ask with @ tags). Swap in a real screen recording before posting (plan rule: real recordings only).
// Needs app.js + pov.js (typing, answerTyping, scanFlow) loaded first.
(() => {
  const ink = '#1A1814';
  // Night routine on the demo shelf (CeraVe + The Ordinary, real products, as the app would list them).
  const PM = [['Foaming Facial Cleanser', 'Cleanser · CeraVe'], ['Glycolic Acid 7% Toning Solution', 'Toner · The Ordinary'],
              ['Retinol 0.5% in Squalane', 'Serum · The Ordinary'], ['PM Facial Moisturizing Lotion', 'Moisturizer · CeraVe']];
  const CONFLICT = { issue: 'Glycolic acid and retinol on the same night can leave skin dry and irritated.',
                     products: 'Glycolic Acid 7% Toning Solution + Retinol 0.5% in Squalane', fix: 'Use them on alternate nights.' };

  // RoutineView (Features/Routine/RoutineView.swift): header, step rows, Check for conflicts -> result.
  // st { phase: 'idle'|'loading'|'result', press, th }
  SCREENS.routine = (st) => {
    const row = (p, i) => `<div style="display:flex;align-items:center;gap:12px;padding:12px;background:var(--cream);border:1px solid var(--line);border-radius:16px;box-shadow:0 1px 2px rgba(26,24,20,.04),0 1px 3px rgba(26,24,20,.06);margin-bottom:8px">
      <span style="width:36px;height:36px;border-radius:50%;background:var(--chip);display:flex;align-items:center;justify-content:center;font:400 13px 'JetBrains Mono';color:var(--mu);flex:none">${i + 1}</span>
      <span style="flex:1;min-width:0"><span style="display:block;font:600 17px 'DM Sans';white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${p[0]}</span><span style="display:block;font-size:14px;color:var(--mu);margin-top:3px">${p[1]}</span></span></div>`;
    let block = '';
    if (st.phase === 'idle') block = `<div style="height:52px;border-radius:14px;background:var(--cream);border:1px solid var(--line);display:flex;align-items:center;justify-content:center;gap:8px;font:600 16px 'DM Sans';transform:scale(${st.press ? .97 : 1})">${ic('spark', 'color:var(--ink)')}Check for conflicts</div>`;
    if (st.phase === 'loading') block = `<div class="card" style="display:flex;align-items:center;gap:12px"><i style="width:20px;height:20px;border-radius:50%;border:2.5px solid var(--line);border-top-color:var(--p);display:block;transform:rotate(${(st.th || 0) * 420}deg)"></i><span style="font-size:14px;color:var(--mu)">Checking both routines…</span></div>`;
    if (st.phase === 'result') block = `<div style="display:flex;align-items:center;gap:12px;margin-bottom:12px"><img src="ugc/DropWarning.png" style="width:64px;height:64px;object-fit:contain"><span style="font:600 17px 'DM Sans'">1 conflict to sort out</span></div>
      <div class="card" style="background:var(--cbg);border-color:rgba(116,60,43,.18);display:flex;gap:12px;align-items:flex-start">
        <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="#743C2B" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="flex:none;margin-top:2px"><path d="M12 4l9 16H3zM12 10v4M12 17h.01"/></svg>
        <div style="display:flex;flex-direction:column;gap:6px"><div style="font-size:16px;line-height:1.35"><b style="font-weight:600">Conflict: </b>${CONFLICT.issue}</div>
        <div style="font:400 12px 'JetBrains Mono';color:var(--mu);line-height:1.4">${CONFLICT.products}</div>
        <div style="font:600 15px 'DM Sans';color:var(--cfg)">${CONFLICT.fix}</div></div></div>`;
    return `${sbar(false)}<div style="position:absolute;top:58px;left:12px;width:40px;height:40px;border-radius:50%;background:rgba(255,254,250,.85);border:1px solid rgba(26,24,20,.08);display:flex;align-items:center;justify-content:center;font-size:18px;z-index:5">${ic('back', 'stroke-width:2.4')}</div>
      <div class="page" style="padding-top:12px">
        <div style="display:flex;align-items:center;justify-content:space-between"><span class="serif" style="font-size:34px;padding-left:44px">Routine</span>
          <div class="sg" style="width:150px"><div>AM</div><div class="on">PM</div></div></div>
        <div style="display:flex;justify-content:space-between;margin:8px 0 14px"><span style="font-size:17px;color:var(--mu)">4 steps · ~4 minutes</span><span style="font:600 15px 'DM Sans';color:var(--p)">Reorder</span></div>
        ${PM.map(row).join('')}
        <div style="margin-top:4px">${block}</div>
        <div style="margin-top:10px;height:50px;border-radius:14px;border:1.5px dashed rgba(163,88,72,.45);display:flex;align-items:center;justify-content:center;font:600 15px 'DM Sans';color:var(--p)">+ Add step from shelf</div>
      </div>`;
  };

  // Each kit: dur, run(u) -> { layers, touch, zoom:{s, x, y} } (screen points), beats: [u, overlay key]
  const KITS = {
    // A: Routine -> Check for conflicts -> 1 conflict -> zoom on the card
    A: { dur: 7.2, run(u) {
      const phase = u < 1.5 ? 'idle' : u < 2.6 ? 'loading' : 'result';
      let touch = null; if (u >= 1.2 && u < 1.5) touch = [196, 474];
      const z = u < 4.2 ? 1 : 1 + .1 * ease((u - 4.2) / .7);
      return { layers: [{ s: 'routine', st: { phase, press: u >= 1.25 && u < 1.5, th: u } }], touch, scroll: phase === 'result' ? 150 * ease((u - 2.7) / .5) : 0, zoom: { s: z, x: 196, y: 560 } };
    } },
    // B: real scan -> product found -> verdict -> zoom to "Why this verdict"
    B: { dur: 7.4, run(u) {
      const L = []; scanFlow(u, L);
      return { layers: L, touch: null, scroll: u < 5.4 ? 0 : 300 * ease((u - 5.4) / .9), zoom: { s: 1, x: 196, y: 426 } };
    } },
    // C: Ask, @ tag two products, same-night question, answer
    C: { dur: 9.0, run(u) {
      const shelf = { g: ['Glycolic Acid 7% Toning Solution', 'ProductDropper.png', '#E3EAD7'], r: ['Retinol 0.5% in Squalane', 'ProductDropper.png', '#EED2CC'] };
      const tg = n => `<b style="color:var(--p);font-weight:600">@${n}</b>`;
      const ans = '<b>Glycolic Acid 7%</b> and <b>Retinol 0.5%</b> are both strong actives. Layering them on the same night can leave skin dry, tight or irritated.<br><br>Try them on <b>alternate nights</b>, and follow either one with your <b>PM Facial Moisturizing Lotion</b>.';
      const st = { th: u }; let touch = null;
      if (u >= .25 && u < .5) touch = [150, 690];
      if (u >= .45 && u < 4.75) {
        st.kb = true;
        if (u < 1.35) { const ty = typing('Can I use @', .5, 13, u); st.input = ty.text; st.hi = ty.hi; }
        else if (u < 1.95) { const ty = typing('Gl', 1.4, 6, u); st.input = 'Can I use @' + ty.text; st.hi = ty.hi; st.mention = [shelf.g]; }
        else if (u < 2.15) { st.input = 'Can I use @Gl'; st.mention = [shelf.g]; st.mHot = 0; touch = [150, 425]; }
        else if (u < 2.85) { const ty = typing(' and @', 2.2, 11, u); st.input = 'Can I use ' + tg(shelf.g[0]) + ty.text; st.hi = ty.hi; }
        else if (u < 3.35) { const ty = typing('Re', 2.9, 6, u); st.input = 'Can I use ' + tg(shelf.g[0]) + ' and @' + ty.text; st.hi = ty.hi; st.mention = [shelf.r]; }
        else if (u < 3.55) { st.input = 'Can I use ' + tg(shelf.g[0]) + ' and @Re'; st.mention = [shelf.r]; st.mHot = 0; touch = [150, 425]; }
        else { const ty = typing(' on the same night?', 3.6, 19, u); st.input = 'Can I use ' + tg(shelf.g[0]) + ' and ' + tg(shelf.r[0]) + ty.text; st.hi = ty.hi; }
      }
      if (u >= 4.6 && u < 4.8) touch = [357, 540];
      if (u >= 4.75) { st.q = 'Can I use <b style="font-weight:600">@Glycolic Acid 7%</b> and <b style="font-weight:600">@Retinol 0.5%</b> on the same night?'; st.kb = false; st.input = ''; }
      if (u >= 4.8 && u < 5.4) st.thinking = true;
      if (u >= 5.4) st.answer = answerTyping(ans, 5.4, 88, u);
      return { layers: [{ s: 'ask', st }], touch, scroll: 0, zoom: { s: 1, x: 196, y: 426 } };
    } },
  };
  // BA: scan first, then the routine check (reel 10)
  KITS.BA = { dur: 9.6, run(u) { return u < 4.4 ? KITS.B.run(u) : KITS.A.run(u - 4.4 + 1.0); } };

  // Reaction assets: AI-generated (Higgsfield/Kling), owned. top = hook text y (px of 1920), fx/fy = zoom focus.
  const ASSET = {
    shock: { seq: 'react/shock', frames: 91, top: 1240, fx: 50, fy: 40 },
    shock2: { seq: 'react/shock', frames: 91, from: 40, top: 300, fx: 52, fy: 38, flip: true },
    hands: { img: 'photos/h1-hook.jpg', top: 1250, fx: 50, fy: 34 },
    hands2: { img: 'photos/h1-hook.jpg', top: 1250, fx: 50, fy: 34, flip: true },
    chin: { img: 'photos/n15-touchface.jpg', top: 250, fx: 50, fy: 36 },
    chin2: { img: 'photos/n15-touchface.jpg', top: 250, fx: 48, fy: 40, flip: true },
    skeptic: { img: 'photos/r1-frustrated.jpg', top: 260, fx: 50, fy: 42 },
    skeptic2: { img: 'photos/r1-frustrated.jpg', top: 260, fx: 50, fy: 42, flip: true },
    phone: { img: 'photos/r2-phone.jpg', top: 250, fx: 50, fy: 45 },
    phone2: { img: 'photos/r2-phone.jpg', top: 250, fx: 52, fy: 40, flip: true },
    smirk: { img: 'photos/r3-bin.jpg', top: 250, fx: 50, fy: 40 },
  };

  // The 14 reels from the plan (hook word for word, overlays per beat, cues max 2: [name, seconds into reel]).
  window.REELS = [
    { n: 1, ref: '01_4486likes_molly_DcP2lsVvi20', top: 480, shot: 'Eyes squeezed shut, wincing, sleeve pulled up over mouth. Low selfie angle from chest height, ceiling behind. Text upper third.', t: 'REGRET', a: 'shock', hook: '4 years of layering random serums in chaos and I just find this now... like wtf 😭', kit: 'A',
      beats: ['put my whole night routine in', 'asked it to check everything', 'it found a clash 😳', 'and told me exactly which two + what to do instead'], cues: [['scratch', 3.0]] },
    { n: 2, ref: '13_354likes_molly_Db0Q9DjEgyt', top: 480, shot: 'Walking outside, phone held high at arm\'s length looking down, half-smile, keeps walking. Text upper third.', t: 'FRIEND POV', a: 'phone', hook: '"how do you know which of your products clash??" 🤨', kit: 'A',
      beats: ['I don\'t. this does', 'one tap', 'caught this one 👀', 'explains why + gives the fix'], cues: [['ding', 3.0]] },
    { n: 3, ref: '18_204likes_lucy_DbdoxzRTTC4', top: 470, shot: 'Close selfie, squinting frown, head tilted, skeptical "really?" face. Text upper third.', t: 'COMPETITOR CALL OUT', a: 'skeptic', hook: 'I can\'t believe people STILL google "can I mix these" at 11pm 😭', kit: 'C',
      beats: ['just tag your products', 'and ask', 'it checks YOUR exact products', 'in plain words, not 12 tabs'], cues: [['key', 3.1], ['key', 3.3]] },
    { n: 4, ref: '16_257likes_lucy_DcF5dB1xMIV', top: 960, shot: 'Chin resting on fist, side-eye off camera, bored-sad pout. Text mid-frame over the hand.', t: 'WISH SOMEONE TOLD ME', a: 'chin', hook: 'i WISH someone told me about this skincare app earlier 🥲', kit: 'A',
      beats: ['you put your routine in', 'it checks every product against each other', 'mine had a clash 🙃', 'and it tells you what to change'], cues: [['dun', 0.2]] },
    { n: 5, ref: '02_1470likes_molly_DdMVeUlDIIl', top: 520, shot: 'Same as reel 1: wince, sleeve over mouth, low angle. Text upper third.', t: 'REGRET', a: 'hands', hook: '3 years of buying every serum the internet told me to and I just find this now 😭', kit: 'B',
      beats: ['now I scan before I buy', 'it reads every ingredient', 'and tells me what each one does'], cues: [['ding', 0.4]] },
    { n: 6, ref: '14_316likes_molly_DdXz-1PHP4P', top: 960, shot: 'Mid-task at the counter (pouring/prepping), side glance to camera, unimpressed. Text mid-frame.', t: 'COMPETITOR CALL OUT', a: 'smirk', hook: 'I can\'t believe people STILL put 5 actives on their face without checking 😭', kit: 'A',
      beats: ['my "routine" 💀', 'checked it', 'yeah...', 'now I know what not to stack'], cues: [['boom', 3.0]] },
    { n: 7, ref: '12_372likes_molly_Dc_TDsOjU0D', top: 960, shot: 'Sitting at a table, glances down then up with a small knowing smile. Text mid-frame, quote marks.', t: 'FRIEND POV', a: 'phone2', hook: '"wait how did you know not to use those two on the same night??" 😳', kit: 'A',
      beats: ['my app told me lol', 'it checked them together', 'it flagged them', 'and what to do instead'], cues: [['error', 5.7]] },
    { n: 8, ref: '17_233likes_molly_DdsoE-rjRPw', top: 430, shot: 'Face squished on hand, eyes closed, "I give up" slump. Very close selfie. Text upper third.', t: 'WDYM', a: 'shock2', hook: 'wdym i\'ve been doing skincare for 6 years and i\'m just finding this now.. like wtf 😭', kit: 'B',
      beats: ['you just scan it', 'it checks every ingredient', 'in words I actually understand'], cues: [['scratch', 3.0]] },
    { n: 9, ref: '24_158likes_molly_Dbstx0xv98v', top: 390, shot: 'Fake-crying into sleeve, glasses, very close. Text near the top.', t: 'REGRET', a: 'hands2', hook: '5 years of googling which serums I can mix and I just find this now... 😭', kit: 'C',
      beats: ['now I just tag them', 'and ask', 'it answers for MY products', 'alternate nights, got it 📝'], cues: [['pop', 3.0]] },
    { n: 10, ref: '21_167likes_lucy_DdwJ13BDUNb', top: 890, shot: 'Hand over mouth, eyes wide, frozen. Straight-on selfie. Text mid-frame over the hand.', t: 'WISH SOMEONE TOLD ME', a: 'chin2', hook: 'i WISH someone told me to check my products BEFORE layering them 🥲', kit: 'BA',
      beats: ['scan each product once', 'it reads the ingredients', 'then checks them together', 'and flags what clashes'], cues: [['dun', 0.2]] },
    { n: 11, ref: '15_263likes_lucy_DbLLMiFzf6U', top: 460, shot: 'Mid-sentence disbelief, mouth open, slight head shake. Text upper third, quote marks.', t: 'COMPETITOR CALL OUT', a: 'skeptic2', hook: 'I can\'t believe people STILL only read the front of the bottle 😭', kit: 'B',
      beats: ['the back is where it\'s at', 'every ingredient, checked', 'explained one by one'], cues: [['click', 3.0]] },
    { n: 12, ref: '11_417likes_molly_DdRFvdGgBIy', top: 520, shot: 'Hand over mouth, eyes closed, laughing-crying, glasses. Text upper third.', t: 'JUST FOUND THIS', a: 'hands', hook: 'i can\'t believe i JUST found this app for checking my skincare 😭', kit: 'A',
      beats: ['put your products in', 'tap one button', 'it finds clashes', 'and tells you why'], cues: [['chime', 3.0]] },
    { n: 13, ref: '23_159likes_molly_DeCKKPkH1Ph', top: 960, shot: 'At a table, looks down at phone, smug little smile. Text mid-frame, quote marks.', t: 'FRIEND POV', a: 'phone', hook: '"how do you always know what order your products go in???" 🤨', kit: 'A',
      beats: ['it keeps them in order', 'checks them together', 'flags anything that clashes', 'and the fix 🫶'], cues: [['ding', 3.0]] },
    { n: 14, ref: '20_174likes_lucy_DaIBvXNTb4N', top: 960, shot: 'Hand over mouth, eyes wide, then softens into a smile. Text mid-frame over the hand.', t: 'KISS THE MAKER', a: 'shock', hook: 'i wish i could KISS the person who made this app 😭💕', kit: 'A',
      beats: ['my whole night routine', 'one tap', 'found my clash', 'told me why + the fix'], cues: [['pop', 0.6]] },
  ];
  // Beat times (u into the demo) per kit.
  window.BEAT_AT = { A: [0, 1.2, 2.7, 4.2], B: [0, 3.7, 5.4], C: [0, 4.6, 5.6, 7.6], BA: [0, 3.7, 5.0, 6.5] };
  window.KITS = KITS; window.ASSET = ASSET;
})();
