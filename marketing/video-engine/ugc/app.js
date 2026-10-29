// Live Skintel screens (393x852) for the POV videos. Pure functions of state -> HTML.
const APP_CSS = `
.scr{--bg:#F4EDE0;--cream:#FFFEFA;--p:#A35848;--ink:#1A1814;--mu:#6B6760;--line:#EAE6DF;--chip:#EFEAE2;
--gbg:#EEF2DD;--gfg:#5C7A4F;--bbg:#FDEAEA;--bfg:#B22B2B;--cbg:#F5E6DC;--cfg:#743C2B;
position:absolute;left:0;top:0;width:393px;height:852px;overflow:hidden;font-family:'DM Sans',sans-serif;color:var(--ink);-webkit-font-smoothing:antialiased;
background:radial-gradient(420px 420px at 0 0,rgba(247,227,214,.55),rgba(247,227,214,0) 100%),radial-gradient(380px 380px at 100% 0,rgba(228,233,234,.5),rgba(228,233,234,0) 100%),#F4EDE0}
.scr *{box-sizing:border-box}
.scr .layer{position:absolute;inset:0;overflow:hidden;background:inherit}
.scr .sb{height:54px;display:flex;align-items:center;justify-content:space-between;padding:6px 34px 0 46px;font:600 17px 'DM Sans';position:relative;z-index:10}
.scr .sb .r{display:flex;gap:6px;align-items:center}
.scr .dark .sb,.scr .sb.dark{color:#fff}
.scr .page{padding:0 22px}
.scr .lbl{font:400 11px 'JetBrains Mono';letter-spacing:1.6px;text-transform:uppercase;color:var(--mu)}
.scr .serif{font-family:'Instrument Serif',serif;font-weight:400}
.scr .card{background:var(--cream);border:1px solid var(--line);border-radius:16px;padding:16px;box-shadow:0 1px 2px rgba(26,24,20,.04),0 1px 3px rgba(26,24,20,.06)}
.scr .chip{display:inline-flex;align-items:center;gap:5px;font:600 12px 'DM Sans';padding:5px 11px;border-radius:99px}
.scr .c-good{background:var(--gbg);color:var(--gfg)}.scr .c-bad{background:var(--bbg);color:var(--bfg)}.scr .c-cau{background:var(--cbg);color:var(--cfg)}.scr .c-neu{background:var(--chip);color:var(--mu)}
.scr .btn{height:52px;border-radius:14px;background:var(--p);color:var(--cream);font:600 16px 'DM Sans';display:flex;align-items:center;justify-content:center;gap:8px;box-shadow:0 6px 16px rgba(163,88,72,.35)}
.scr .sg{display:flex;background:var(--chip);border-radius:99px;padding:3px}
.scr .sg div{flex:1;height:40px;display:flex;align-items:center;justify-content:center;font:500 15px 'DM Sans';color:var(--mu);border-radius:99px}
.scr .sg .on{background:var(--cream);color:var(--ink);font-weight:600;box-shadow:0 1px 3px rgba(26,24,20,.12)}
.scr .bar{height:6px;border-radius:9px;background:var(--line);overflow:hidden}.scr .bar i{display:block;height:100%;background:var(--p);border-radius:9px}
.scr .mark{border-radius:25%;display:flex;align-items:center;justify-content:center;overflow:hidden;flex:none}
.scr .mark img{height:80%}
.scr svg.i{width:1em;height:1em;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}
.scr .tabs{position:absolute;left:16px;right:16px;bottom:34px;display:flex;gap:10px;align-items:center;z-index:15}
.scr .tcap{flex:1;display:flex;padding:4px;border-radius:99px;background:rgba(255,254,250,.86);border:1px solid rgba(255,255,255,.7);box-shadow:0 8px 24px rgba(26,24,20,.10),inset 0 1px 0 rgba(255,255,255,.8)}
.scr .ti{flex:1;height:47px;border-radius:99px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;font:500 12px 'DM Sans';color:var(--ink)}
.scr .ti svg{font-size:22px}.scr .ti.on{color:var(--p);background:rgba(163,88,72,.07)}
.scr .fab{width:56px;height:56px;border-radius:50%;background:radial-gradient(circle at 35% 30%,#C07463,#A35848 60%,#8E4538);color:var(--cream);display:flex;align-items:center;justify-content:center;font-size:24px;box-shadow:0 8px 20px rgba(163,88,72,.4);flex:none}
.scr .home{position:absolute;bottom:8px;left:50%;width:134px;height:5px;margin-left:-67px;border-radius:9px;background:var(--ink);z-index:40}
.scr .nav{height:44px;display:flex;align-items:center;justify-content:space-between;padding:0 16px;font:600 17px 'DM Sans'}
.scr .nav .ic{width:44px;height:44px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:20px;background:rgba(255,254,250,.6);border:1px solid rgba(26,24,20,.08)}
.scr .kb{position:absolute;left:0;right:0;bottom:0;height:291px;background:#D2D4DA;padding:8px 3px 0;z-index:30}
.scr .kr{display:flex;justify-content:center;gap:6px;margin-bottom:11px}
.scr .k{height:43px;width:33px;border-radius:5px;background:#fff;box-shadow:0 1px 0 #898A8D;display:flex;align-items:center;justify-content:center;font:400 23px -apple-system,'DM Sans',sans-serif;color:#000}
.scr .k.g{background:#ABB0BA}
.scr .k.hi{background:#fff;transform:translateY(-6px) scale(1.25);box-shadow:0 4px 10px rgba(0,0,0,.25)}
.scr .touch{position:absolute;width:46px;height:46px;margin:-23px 0 0 -23px;border-radius:50%;background:rgba(255,255,255,.55);border:2px solid rgba(255,255,255,.85);box-shadow:0 0 0 1px rgba(0,0,0,.12),0 4px 14px rgba(0,0,0,.25);z-index:60}
.scr .toast{position:absolute;left:50%;bottom:112px;transform:translateX(-50%);background:var(--ink);color:var(--cream);font:600 14px 'DM Sans';padding:11px 16px;border-radius:99px;display:flex;gap:7px;align-items:center;white-space:nowrap;z-index:50;box-shadow:0 8px 24px rgba(0,0,0,.2)}
.scr .notif{position:absolute;left:10px;right:10px;border-radius:24px;background:rgba(245,242,238,.82);backdrop-filter:blur(20px);display:flex;gap:12px;align-items:center;padding:13px 14px;z-index:50;box-shadow:0 6px 20px rgba(0,0,0,.18)}
.scr .notif img{width:40px;height:40px;border-radius:10px}
`;
const IC = {
  sun:'<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  spark:'<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>',
  chart:'<rect x="3" y="10" width="5" height="11" rx="1.5"/><rect x="9.5" y="6" width="5" height="15" rx="1.5"/><rect x="16" y="3" width="5" height="18" rx="1.5"/>',
  person:'<circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/>',
  plus:'<path d="M12 5v14M5 12h14"/>', back:'<path d="M15 5l-7 7 7 7"/>', share:'<path d="M12 15V3M8 7l4-4 4 4"/><path d="M6 11H5v10h14V11h-1"/>',
  up:'<path d="M12 19V5M6 11l6-6 6 6"/>', at:'<circle cx="12" cy="12" r="4"/><path d="M16 8v5a3 3 0 006 0v-1a10 10 0 10-4 8"/>',
  moon:'<path d="M20 14.5A8 8 0 019.5 4a8 8 0 1010.5 10.5z"/>', bulb:'<path d="M9 18h6M10 21h4M12 3a6 6 0 00-3.5 10.9c.7.5 1 1.2 1 2.1h5c0-.9.3-1.6 1-2.1A6 6 0 0012 3z"/>',
  check:'<path d="M5 12.5l4.5 4.5L19 7.5"/>', kb:'<rect x="2" y="6" width="20" height="13" rx="2"/><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M7 15h10"/>',
  doc:'<path d="M7 3h7l5 5v13H7z"/><path d="M14 3v5h5M10 13h6M10 17h6"/>', bolt:'<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>',
  clock:'<path d="M3 12a9 9 0 109-9 9 9 0 00-7 3.4"/><path d="M3 4v4h4M12 7v5l3 2"/>', pen:'<path d="M12 20h9M16.5 3.5a2.1 2.1 0 013 3L7 19l-4 1 1-4z"/>',
  x:'<path d="M6 6l12 12M18 6L6 18"/>',
  drop:'<path d="M12 3s6 6.5 6 11a6 6 0 01-12 0c0-4.5 6-11 6-11z"/>',
  shield:'<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/>',
  half:'<circle cx="12" cy="12" r="9"/><path d="M12 3v18"/><path d="M12 3a9 9 0 010 18z" fill="currentColor"/>', tray:'<path d="M3 13h5l1.5 2.5h5L16 13h5"/><path d="M5 6h14l2 7v6H3v-6z"/>',
};
const ic = (n, s = '') => `<svg class="i" viewBox="0 0 24 24" style="${s}">${IC[n]}</svg>`;
const sbar = (dark, time = '9:41') => `<div class="sb ${dark ? 'dark' : ''}"><span>${time}</span><span class="r"><svg width="18" height="12" viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1" fill="currentColor"/><rect x="5" y="5.5" width="3" height="6.5" rx="1" fill="currentColor"/><rect x="10" y="3" width="3" height="9" rx="1" fill="currentColor"/><rect x="15" y="0" width="3" height="12" rx="1" fill="currentColor"/></svg><svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.5" stroke="currentColor" opacity=".4" fill="none"/><rect x="2" y="2" width="18" height="9" rx="2" fill="currentColor"/></svg></span></div>`;
const tabbar = (on) => {
  const t = (k, n, l) => `<div class="ti ${on === k ? 'on' : ''}">${ic(n)}<span>${l}</span></div>`;
  return `<div style="position:absolute;left:0;right:0;bottom:0;height:130px;background:linear-gradient(rgba(244,237,224,0),rgba(244,237,224,.92) 55%);z-index:14"></div><div class="tabs"><div class="tcap">${t('today','sun','Today')}${t('ask','spark','Ask')}</div><div class="fab">${ic('plus','stroke-width:2.6')}</div><div class="tcap">${t('insights','chart','Insights')}${t('you','person','You')}</div></div>`;
};
const mk = (img, bg, size) => `<div class="mark" style="width:${size}px;height:${size}px;background:${bg}"><img src="ugc/${img}"></div>`;
const clamp01 = x => Math.max(0, Math.min(1, x));
const eo = x => { x = clamp01(x); return 1 - Math.pow(1 - x, 3); };
const typed = (s, t0, cps, t) => s.slice(0, Math.max(0, Math.floor((t - t0) * cps)));

// keyboard; hi = char currently pressed
function keyboard(hi) {
  const row = (ks) => `<div class="kr">${ks.split('').map(k => `<div class="k ${hi && hi.toLowerCase() === k ? 'hi' : ''}">${k}</div>`).join('')}</div>`;
  return `<div class="kb">${row('qwertyuiop')}${row('asdfghjkl')}<div class="kr"><div class="k g" style="width:42px">⇧</div>${'zxcvbnm'.split('').map(k => `<div class="k ${hi && hi.toLowerCase() === k ? 'hi' : ''}">${k}</div>`).join('')}<div class="k g" style="width:42px">⌫</div></div>
  <div class="kr"><div class="k g" style="width:88px;font-size:16px">123</div><div class="k ${hi === ' ' ? 'hi' : ''}" style="width:186px;font-size:16px">space</div><div class="k g" style="width:88px;font-size:16px">return</div></div></div>`;
}

// ---------- Ask ----------
// st: {input, kb, hi, mention:[names]|null, q, qChips, thinking, answer, sendHot}
function askScreen(st) {
  const msgs = st.q ? `<div style="display:flex;justify-content:flex-end"><div style="max-width:82%;background:var(--p);color:var(--cream);font-size:16px;line-height:1.4;padding:11px 16px;border-radius:20px">${st.q}</div></div>` : '';
  const ans = st.thinking ? `<div style="display:flex;gap:12px;margin-top:16px"><div style="width:28px;height:28px;border-radius:50%;background:var(--p);color:var(--cream);display:flex;align-items:center;justify-content:center;font-size:14px;flex:none">${ic('spark','stroke-width:2.2')}</div><div style="display:flex;gap:5px;padding-top:12px">${[0,1,2].map(i => `<i style="width:7px;height:7px;border-radius:50%;background:var(--mu);opacity:${.3 + .7 * Math.abs(Math.sin(st.th * 5 + i))}"></i>`).join('')}</div></div>`
    : st.answer ? `<div style="display:flex;gap:12px;margin-top:16px"><div style="width:28px;height:28px;border-radius:50%;background:var(--p);color:var(--cream);display:flex;align-items:center;justify-content:center;font-size:14px;flex:none">${ic('spark','stroke-width:2.2')}</div><div style="font-size:16px;line-height:1.5">${st.answer}</div></div>` : '';
  const empty = !st.q ? `<div style="text-align:center;margin-top:120px"><div class="serif" style="font-size:30px">Ask about your skin</div><div style="font-size:15px;color:var(--mu);margin-top:8px;padding:0 30px;line-height:1.4">Ask about your routine, ingredients or a reaction. Answers use your shelf and routine.</div></div>` : '';
  const bottom = st.kb ? 291 : 100;
  const mention = st.mention ? `<div style="margin:0 16px 8px;background:var(--cream);border:1px solid var(--line);border-radius:18px;box-shadow:0 8px 24px rgba(26,24,20,.08);overflow:hidden"><div class="lbl" style="padding:10px 14px 4px">Your shelf</div>${st.mention.map((m, i) => `<div style="display:flex;gap:10px;align-items:center;padding:9px 14px;${st.mHot === i ? 'background:rgba(163,88,72,.08)' : ''}">${mk(m[1], m[2], 30)}<span style="font:500 15px 'DM Sans'">${m[0]}</span></div>`).join('')}</div>` : '';
  const chips = !st.kb && !st.q && st.chips ? `<div style="display:flex;gap:8px;padding:0 16px 8px;overflow:hidden">${st.chips.map((c, i) => `<div style="flex:none;height:38px;padding:0 14px;border-radius:99px;background:${st.chipHot === i ? '#F1E3DC' : 'var(--cream)'};border:1px solid var(--line);display:flex;align-items:center;font:500 14px 'DM Sans'">${c}</div>`).join('')}</div>` : '';
  const caret = st.kb ? `<i style="display:inline-block;width:2px;height:19px;background:var(--p);vertical-align:-3px;margin-left:1px;opacity:${Math.floor(st.th * 2.5) % 2 ? 0 : 1}"></i>` : '';
  const inputTxt = st.input ? `<span style="color:var(--ink)">${st.input}</span>${caret}` : (st.kb ? caret : '<span style="color:#A9A49C">Ask about your skin or products</span>');
  return `${sbar(false)}<div class="nav" style="height:54px;position:relative"><span style="position:absolute;left:0;right:0;text-align:center">Ask Skinstel</span><span style="margin-left:auto;display:flex;align-items:center;gap:30px;height:44px;padding:0 16px;border-radius:99px;background:rgba(255,254,250,.6);border:1px solid rgba(26,24,20,.08);font-size:21px">${ic('clock','color:var(--p);stroke-width:2')}${ic('pen','color:#B5AFA7')}</span></div>
  <div class="page" style="padding-top:14px">${empty}${msgs}${ans}</div>
  <div style="position:absolute;left:0;right:0;bottom:${bottom}px;z-index:20">${mention}${chips}
    <div style="margin:0 16px 8px;border-radius:26px;background:rgba(255,254,250,.96);border:1px solid var(--line);box-shadow:0 8px 24px rgba(26,24,20,.06)">
      <div style="padding:14px 18px 0;font-size:16px;min-height:36px">${inputTxt}</div>
      <div style="display:flex;align-items:center;gap:8px;padding:8px 8px 8px 10px">
        <div style="width:34px;height:34px;border-radius:50%;background:var(--chip);display:flex;align-items:center;justify-content:center;font-size:15px">${ic('at','stroke-width:2.2')}</div>
        <div style="display:flex;background:var(--chip);border-radius:99px;padding:3px"><div style="height:30px;padding:0 12px;border-radius:99px;background:var(--p);color:var(--cream);display:flex;align-items:center;gap:5px;font:600 14px 'DM Sans'">${ic('moon','font-size:11px;fill:currentColor')}Luna</div><div style="height:30px;padding:0 12px;display:flex;align-items:center;gap:5px;font:600 14px 'DM Sans';color:var(--mu)">${ic('sun','font-size:11px')}Sol</div></div>
        <div style="flex:1"></div><div style="width:36px;height:36px;border-radius:50%;background:${st.input ? 'var(--p)' : 'rgba(107,103,96,.35)'};color:var(--cream);display:flex;align-items:center;justify-content:center;font-size:16px">${ic('up','stroke-width:2.8')}</div>
      </div></div>
    ${st.kb ? '' : `<div style="text-align:center;font-size:12px;color:var(--mu);margin-top:2px">Answers can be wrong. Skinstel isn't a doctor.</div>`}
  </div>${st.kb ? keyboard(st.hi) : tabbar('ask')}`;
}

// ---------- Today ----------
// st: {slot:'am'|'pm', steps:[[label,name,done]], log:null|idx, streak, evening}
function todayScreen(st) {
  const steps = st.steps, n = steps.filter(s => s[2]).length;
  const logC = [['Clear','#5C7A4F'],['A bit off','rgba(163,88,72,.4)'],['Irritated','rgba(163,88,72,.7)'],['Breaking out','#A35848']];
  return `${sbar(false, st.time || '9:41')}<div class="page" style="padding-top:14px">
  <div class="lbl">${st.date || 'Friday, Oct 24'}</div>
  <div class="serif" style="font-size:34px;line-height:1.08;margin-top:8px">${st.slot === 'pm' ? 'Good evening, Riya' : 'Good morning, Riya'}</div>
  <div style="display:flex;gap:8px;align-items:center;margin-top:10px"><span class="chip ${st.slot === 'am' ? 'c-good' : 'c-neu'}">AM ${st.am || '5 of 7'}</span><span class="chip ${st.slot === 'pm' ? 'c-good' : 'c-neu'}">PM ${st.pm || '4 of 7'}</span><span style="font-size:12px;color:var(--mu)">this week</span></div>
  <div class="card" style="margin-top:16px">
    <div style="display:flex;justify-content:space-between;align-items:baseline"><span class="serif" style="font-size:24px">${st.slot === 'pm' ? 'Tonight' : 'This morning'}</span><span style="font:400 12px 'JetBrains Mono';color:${n === steps.length ? 'var(--gfg)' : 'var(--mu)'}">${n === steps.length ? 'Done' : `${n} of ${steps.length}`}</span></div>
    <div class="sg" style="margin-top:12px"><div class="${st.slot === 'am' ? 'on' : ''}">AM</div><div class="${st.slot === 'pm' ? 'on' : ''}">PM</div></div>
    <div class="bar" style="margin-top:12px"><i style="width:${(st.barW != null ? st.barW : n / steps.length) * 100}%;transition:none"></i></div>
    ${steps.map((r, i) => `<div style="display:flex;align-items:center;gap:8px;min-height:56px;${i ? 'border-top:1px solid var(--line)' : ''}">
      <div style="width:44px;height:44px;display:flex;align-items:center;justify-content:center"><div style="width:28px;height:28px;border-radius:50%;border:1.5px solid ${r[2] ? 'var(--p)' : 'var(--line)'};background:${r[2] ? 'var(--p)' : 'var(--cream)'};display:flex;align-items:center;justify-content:center;color:var(--cream);font-size:15px;transform:scale(${r[3] || 1})">${r[2] ? ic('check','stroke-width:3') : ''}</div></div>
      <div><div style="font:400 10.5px 'JetBrains Mono';letter-spacing:1px;color:var(--mu)">${r[0]}</div><div style="font:500 16px 'DM Sans';color:${r[2] ? 'var(--mu)' : 'var(--ink)'};${r[2] ? 'text-decoration:line-through;text-decoration-color:rgba(107,103,96,.5)' : ''}">${r[1]}</div></div></div>`).join('')}
    <div class="btn" style="margin-top:10px">Mark all done</div>
  </div>
  <div class="card" style="margin-top:16px">
    <div style="display:flex;justify-content:space-between;align-items:center"><span class="lbl">Skin log</span><span class="chip c-cau">${st.streak || '6-day streak'}</span></div>
    <div style="font:600 17px 'DM Sans';margin-top:12px">How did your skin wake up?</div>
    <div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:12px">${logC.map((c, i) => `<div style="height:42px;padding:0 13px;border-radius:99px;border:1px solid ${st.log === i ? 'var(--p)' : 'var(--line)'};background:${st.log === i ? 'var(--p)' : 'var(--cream)'};color:${st.log === i ? 'var(--cream)' : 'var(--ink)'};display:flex;align-items:center;gap:7px;font:600 15px 'DM Sans'"><i style="width:8px;height:8px;border-radius:50%;background:${st.log === i ? 'var(--cream)' : c[1]}"></i>${c[0]}</div>`).join('')}</div>
    <div style="display:flex;justify-content:space-between;margin-top:12px;font-size:14px"><span style="color:var(--mu)">${st.log != null ? 'Logged for today.' : 'One tap logs today.'}</span><span style="color:var(--p);font-weight:600">Add detail</span></div>
  </div></div>${tabbar('today')}`;
}

// ---------- Scan ----------
function scanScreen(st) {
  return `<div style="position:absolute;inset:0;background:radial-gradient(90% 60% at 28% 18%,#5A4A3E,#2A221C 45%,#0E0C0A)"></div>
  <img src="ugc/scan-raw-noline.png" style="position:absolute;inset:0;width:100%;height:100%">
  <div style="position:absolute;left:66px;right:66px;top:${300 + 100 + 85 * Math.sin(st.th * 3.2)}px;height:3px;border-radius:3px;background:#E7B8A6;box-shadow:0 0 18px 6px rgba(163,88,72,.55)"></div>`;
}

// ---------- Verdict ----------
function verdictScreen(st) {
  const r = st.ring == null ? 1 : st.ring, num = Math.round(86 * r);
  return `${sbar(false)}<div class="nav"><span class="ic">${ic('back')}</span><span>Analysis</span><span class="ic">${ic('share')}</span></div>
<div class="page" style="padding-top:12px">
  <div style="display:flex;gap:12px;align-items:center">${mk('ProductPump.png','#D6E0EA',40)}<div><div style="font:600 17px 'DM Sans'">CeraVe Foaming Facial Cleanser</div><div style="font:400 12px 'JetBrains Mono';color:var(--mu)">24 ingredients · barcode</div></div></div>
  <div class="card" style="margin-top:16px;background:linear-gradient(135deg,var(--gbg),var(--cream));border-color:rgba(92,122,79,.22)">
    <div style="display:flex;justify-content:space-between;align-items:center"><span class="chip c-good">GOOD MATCH</span><span style="font:400 12px 'JetBrains Mono';color:var(--mu)">1 flag</span></div>
    <div style="display:flex;align-items:center;gap:22px;margin-top:16px">
      <div style="position:relative;width:118px;height:118px;flex:none"><svg width="118" height="118" viewBox="0 0 118 118"><circle cx="59" cy="59" r="53.5" stroke="#EAE6DF" stroke-width="11" fill="none"/><circle cx="59" cy="59" r="53.5" stroke="#5C7A4F" stroke-width="11" fill="none" stroke-linecap="round" stroke-dasharray="336.2" stroke-dashoffset="${336.2 * (1 - .86 * r)}" transform="rotate(-90 59 59)"/></svg>
        <div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center"><span class="serif" style="font-size:44px;line-height:1">${num}</span><span style="font:400 10px 'JetBrains Mono';letter-spacing:1.4px;color:var(--mu)">MATCH</span></div></div>
      <div style="flex:1">${[['Good for you','9','var(--gfg)'],['Watch','1','var(--cfg)'],['Red flags','0','var(--ink)']].map((x, i) => `<div style="display:flex;justify-content:space-between;padding:9px 0;${i < 2 ? 'border-bottom:1px solid var(--line)' : ''}"><span style="font-size:14px;color:var(--mu)">${x[0]}</span><span style="font:600 16px 'DM Sans';color:${x[2]}">${x[1]}</span></div>`).join('')}</div>
    </div>
    <div style="font-size:17px;line-height:1.4;margin-top:16px">A gentle foaming cleanser with ceramides and niacinamide. One ingredient to watch if your skin runs dry.</div>
  </div>
  <div class="serif" style="font-size:24px;margin-top:22px">Why this verdict</div>
  ${[['var(--cfg)','Sodium Lauroyl Sarcosinate','can feel tight on very dry skin.'],['var(--gfg)','Niacinamide','calms redness and helps balance oil.'],['var(--gfg)','Ceramide NP','supports your skin barrier.']].map(x => `<div class="card" style="margin-top:12px;display:flex;gap:12px"><i style="width:8px;height:8px;border-radius:50%;background:${x[0]};margin-top:8px;flex:none"></i><div style="font-size:16px;line-height:1.35"><b style="font-weight:600">${x[1]}</b> — ${x[2]}</div></div>`).join('')}
  <div class="btn" style="margin-top:18px;transform:scale(${st.press ? .96 : 1})">Save to shelf</div>
</div>`;
}

// ---------- Add product (from verdict) ----------
function formScreen(st) {
  const opts = [['Worked','var(--gfg)'],['Unsure','var(--mu)'],['Broke out','var(--bfg)']];
  return `${sbar(false)}<div class="nav"><span style="color:var(--p);font-weight:400">Cancel</span><span>Add product</span><span style="width:50px"></span></div>
<div class="page" style="padding-top:10px">
  <div class="lbl" style="margin-top:8px">Product name</div><div class="card" style="padding:13px 14px;margin-top:6px;font:500 16px 'DM Sans'">Foaming Facial Cleanser</div>
  <div class="lbl" style="margin-top:14px">Brand</div><div class="card" style="padding:13px 14px;margin-top:6px;font-size:16px">CeraVe</div>
  <div class="lbl" style="margin-top:14px">Category · Cleanser</div>
  <div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap">${['Cleanser','Toner','Serum','Moisturizer','Sunscreen'].map((c, i) => `<span class="chip ${i ? 'c-neu' : ''}" style="${i ? '' : 'background:var(--p);color:var(--cream)'};font-size:13px;padding:7px 12px">${c}</span>`).join('')}</div>
  <div class="lbl" style="margin-top:18px">How did your skin react?</div>
  <div style="display:flex;background:var(--chip);border-radius:99px;padding:4px;margin-top:8px">${opts.map(o => `<div style="flex:1;height:42px;border-radius:99px;display:flex;align-items:center;justify-content:center;gap:6px;font:600 15px 'DM Sans';${st.react === o[0] ? `background:var(--cream);color:${o[1]};box-shadow:0 1px 3px rgba(26,24,20,.12)` : 'color:var(--mu)'}">${st.react === o[0] ? ic('check','font-size:15px;stroke-width:2.6') : ''}${o[0]}</div>`).join('')}</div>
  <div class="lbl" style="margin-top:16px">Ingredients</div>
  <div class="card" style="margin-top:6px;padding:14px 16px">
    <div class="serif" style="font-size:21px">What it's good for</div>
    ${[['drop','Hydration','Glycerin, Hyaluronic Acid'],['shield','Barrier support','Ceramide NP, Ceramide AP, Cholesterol'],['half','Even tone','Niacinamide']].map((r, i) => `<div style="display:flex;gap:12px;align-items:center;padding:8px 0;${i ? 'border-top:1px solid var(--line)' : 'margin-top:4px'}"><div style="width:30px;height:30px;border-radius:9px;background:var(--gbg);color:var(--gfg);display:flex;align-items:center;justify-content:center;font-size:15px;flex:none">${ic(r[0])}</div><div><div style="font:600 14.5px 'DM Sans'">${r[1]}</div><div style="font-size:12.5px;color:var(--mu)">${r[2]}</div></div></div>`).join('')}
    <div class="lbl" style="margin-top:8px">Watch for</div>
    <div style="display:flex;gap:8px;align-items:center;margin-top:6px;font-size:13.5px"><i style="width:8px;height:8px;border-radius:50%;background:var(--cfg);flex:none"></i><span><b style="font-weight:600">Sodium Lauroyl Sarcosinate</b> can feel tight on very dry skin</span></div>
    <div style="font:600 14px 'DM Sans';color:var(--p);margin-top:10px">View or edit all 24 ingredients</div>
  </div>
  <div class="lbl" style="margin-top:14px">Notes</div><div class="card" style="padding:12px 14px;margin-top:6px;font-size:15px;color:#A9A49C">Where you bought it, how often you use it…</div>
</div>
<div style="position:absolute;left:0;right:0;bottom:0;padding:14px 22px 30px;background:linear-gradient(rgba(244,237,224,0),#F3ECDF 30%);z-index:20"><div class="btn" style="transform:scale(${st.press ? .96 : 1})">Save to shelf</div></div>`;
}

// ---------- Shelf ----------
const SHELF = [
  ['CeraVe Foaming Facial Cleanser','ProductPump.png','#D6E0EA','Worked'],
  ['Anua Heartleaf 77% Toner','ProductDropper.png','#E3EAD7','Worked'],
  ['Rose Cloud Moisturizer','ProductTube.png','#EED2CC',null],
  ['Petal Glow Serum','ProductDropper.png','#F0DCE0','Broke out'],
  ['Coconut body oil','ProductPump.png','#EFE5D2','Broke out'],
  ['Beauty of Joseon Relief Sun','ProductTube.png','#F3E6C9','Worked'],
  ['The Ordinary Niacinamide 10%','ProductDropper.png','#E6E2EE','Worked'],
];
function shelfScreen(st) {
  const items = st.items || SHELF;
  const chip = (r) => r === 'Worked' ? '<span class="chip c-good">Worked</span>' : r === 'Broke out' ? '<span class="chip c-bad">Broke out</span>' : r === 'Unsure' ? '<span class="chip c-neu">Unsure</span>' : '<span class="chip c-neu" style="opacity:.7">Not tagged</span>';
  return `${sbar(false)}<div class="page" style="padding-top:8px"><div style="display:flex;justify-content:space-between;align-items:center"><div class="serif" style="font-size:34px">Shelf</div><span class="chip c-neu">${items.length} products</span></div>
  <div style="margin-top:14px">${items.map((p, i) => `<div class="card" style="display:flex;gap:12px;align-items:center;padding:12px 14px;margin-top:10px;${st.hot === i ? 'background:#F7EDE6;border-color:rgba(163,88,72,.35)' : ''}${st.fresh === i ? `;transform:translateY(${(1 - eo(st.freshK)) * -20}px);opacity:${eo(st.freshK)}` : ''}">${mk(p[1], p[2], 44)}<div style="flex:1;min-width:0"><div style="font:600 15.5px 'DM Sans';white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${p[0]}</div></div>${chip(p[3])}</div>`).join('')}</div></div>
  ${st.toast ? `<div class="toast" style="opacity:${st.toast}">${ic('check','stroke-width:2.6;font-size:15px')}Saved to shelf</div>` : ''}
  ${st.sheet != null ? `<div style="position:absolute;inset:0;background:rgba(26,24,20,${.3 * st.sheetK});z-index:30"></div><div style="position:absolute;left:0;right:0;bottom:0;transform:translateY(${(1 - eo(st.sheetK)) * 100}%);background:var(--cream);border-radius:28px 28px 0 0;padding:22px 22px 44px;z-index:31">
    <div style="width:38px;height:5px;border-radius:9px;background:var(--line);margin:-10px auto 14px"></div>
    <div style="display:flex;gap:12px;align-items:center">${mk('ProductTube.png','#EED2CC',44)}<div style="font:600 17px 'DM Sans'">Rose Cloud Moisturizer</div></div>
    <div class="lbl" style="margin-top:18px">How did your skin react?</div>
    <div style="display:flex;background:var(--chip);border-radius:99px;padding:4px;margin-top:8px">${[['Worked','var(--gfg)'],['Unsure','var(--mu)'],['Broke out','var(--bfg)']].map(o => `<div style="flex:1;height:42px;border-radius:99px;display:flex;align-items:center;justify-content:center;gap:6px;font:600 15px 'DM Sans';${st.sheet === o[0] ? `background:var(--cream);color:${o[1]};box-shadow:0 1px 3px rgba(26,24,20,.12)` : 'color:var(--mu)'}">${st.sheet === o[0] ? ic('check','font-size:15px;stroke-width:2.6') : ''}${o[0]}</div>`).join('')}</div>
  </div>` : ''}${tabbar('you')}`;
}

// ---------- Triggers ----------
function triggersScreen(st) {
  const b = st.bars == null ? 1 : st.bars;
  return `${sbar(false)}<div style="position:absolute;top:58px;left:12px;width:44px;height:44px;border-radius:50%;background:rgba(255,254,250,.85);display:flex;align-items:center;justify-content:center;font-size:18px;z-index:5">${ic('back','stroke-width:2.4')}</div>
<div class="page" style="padding-top:8px">
  <div class="serif" style="font-size:34px;padding-left:44px">Triggers</div>
  <div style="font-size:17px;color:var(--mu);margin-top:4px">Ingredients your breakouts share</div>
  <div style="display:flex;gap:12px;align-items:center;margin-top:16px"><img src="ugc/DropWarning.png" style="width:80px;height:80px;object-fit:contain"><div><div class="serif" style="font-size:24px">1 possible trigger</div><div style="font-size:14px;color:var(--mu);line-height:1.35">Each is in 2 or more products that broke you out. A pattern to test, not proof.</div></div></div>
  <div class="card" style="margin-top:16px;background:linear-gradient(135deg,var(--bbg),var(--cream));border-color:rgba(178,43,43,.25)">
    <div style="display:flex;justify-content:space-between;align-items:center"><span class="chip c-bad">TOP SUSPECT</span><span style="font:400 12px 'JetBrains Mono';color:var(--bfg)">in 3 of 4 breakouts</span></div>
    <div style="display:flex;gap:12px;margin-top:12px">${mk('ProductTube.png','#EED2CC',52)}<div><div style="font:600 20px 'DM Sans'">Fragrance (Parfum)</div><div style="font-size:14px;color:var(--mu);margin-top:3px">Never in anything that worked for you.</div></div></div>
    <div style="display:flex;gap:6px;margin-top:12px;font-size:14px;line-height:1.35">${ic('bulb','color:var(--p);font-size:15px;flex:none;margin-top:2px')}<span>Why it matters: it's the likeliest link between your breakouts. Check labels for it; scans flag it too.</span></div>
    <div style="display:flex;gap:8px;align-items:flex-end;height:24px;margin-top:12px">${[1,1,0,1].map((h, i) => `<i style="flex:1;height:${h ? 8 + 16 * eo(b * 4 - i * .6) : 8}px;border-radius:8px;background:${h ? 'rgba(178,43,43,.75)' : 'var(--line)'}"></i>`).join('')}</div>
    <div style="font:600 15px 'DM Sans';color:var(--bfg);margin-top:10px">Which products ▾</div>
  </div>
  <div class="serif" style="font-size:24px;margin-top:22px">From your journal</div>
  <div class="card" style="margin-top:12px;background:linear-gradient(135deg,var(--cbg),var(--cream));border-color:rgba(116,60,43,.25)">
    <div style="display:flex;justify-content:space-between;align-items:center"><span class="chip c-cau">WATCHING</span><span style="font:400 12px 'JetBrains Mono';color:var(--cfg)">58% confidence</span></div>
    <div style="font:600 20px 'DM Sans';margin-top:10px">Coconut body oil</div>
    <div style="font-size:14px;color:var(--mu);margin-top:4px">Two of your rough days came 4–6 days after you started it.</div>
  </div>
</div>${tabbar('insights')}`;
}

// ---------- Lock screen ----------
function lockScreen(st) {
  return `<div style="position:absolute;inset:0;background:radial-gradient(120% 70% at 30% 20%,#7A4A3A,#3B2620 55%,#1A1210)"></div>
  ${sbar(true, '')}
  <div style="position:absolute;top:96px;left:0;right:0;text-align:center;color:rgba(255,255,255,.9);font:600 19px 'DM Sans'">${st.date || 'Friday, October 24'}</div>
  <div style="position:absolute;top:118px;left:0;right:0;text-align:center;color:rgba(255,255,255,.95);font:600 96px/1 'DM Sans';letter-spacing:-2px">${st.time || '10:42'}</div>
  ${st.notif != null ? `<div class="notif" style="top:${560 - 30 * (1 - eo(st.notif))}px;opacity:${eo(st.notif)};transform:scale(${st.press ? .97 : 1})"><img src="ugc/AppIcon-1024.png"><div style="flex:1"><div style="display:flex;justify-content:space-between"><b style="font:700 15px 'DM Sans'">${st.title}</b><span style="font-size:13px;color:rgba(60,60,67,.6)">now</span></div><div style="font-size:15px;margin-top:1px">${st.body}</div></div></div>` : ''}
  <div style="position:absolute;bottom:8px;left:50%;width:134px;height:5px;margin-left:-67px;border-radius:9px;background:#fff"></div>`;
}

const SCREENS = { ask: askScreen, today: todayScreen, scan: scanScreen, verdict: verdictScreen, form: formScreen, shelf: shelfScreen, triggers: triggersScreen, lock: lockScreen };

// ---------- Real-camera scanner (photo feed + printed back label) ----------
// st: {th, lock 0..1, sheet: null|1|2, sheetK 0..1}
const BARS = (() => { let x = 0, s = '', seed = 7; const r = () => (seed = (seed * 9301 + 49297) % 233280) / 233280;
  while (x < 128) { const w = 1 + Math.floor(r() * 3), g = 1 + Math.floor(r() * 2.2); s += `<rect x="${x}" y="0" width="${w * .9}" height="46" fill="#151311"/>`; x += w + g; } return s; })();
function scanRealScreen(st) {
  const L = st.lock || 0, k = eo(L);
  const box0 = [51.5, 420, 290, 200], box1 = [120, 492, 153, 98];
  const b = box0.map((v, i) => v + (box1[i] - v) * k);
  const blur = Math.max(0, 1.6 - st.th * 3);
  const jx = Math.sin(st.th * 2.1) * 3 + Math.sin(st.th * 5.3) * 1.2, jy = Math.cos(st.th * 1.7) * 3;
  const zoom = 1 + .05 * k;
  const hint = L > .05 ? 'Looking it up…' : 'Point at the barcode on the back';
  // printed straight onto the tube (multiply keeps the tube's shading); barcode box at feed x135-258, y510-572
  const label = `<div style="position:absolute;left:125px;top:318px;width:143px;height:300px;mix-blend-mode:multiply;filter:blur(.35px);opacity:.92;color:#2b2724;font-family:Arial,sans-serif">
      <div style="font:700 9px Arial;letter-spacing:.8px;color:#3d6b8c">FOAMING FACIAL CLEANSER</div>
      <div style="font:400 6px Arial;margin-top:2px;color:#6b645c">for normal to oily skin · 473 mL</div>
      <div style="font:700 6.4px Arial;letter-spacing:.5px;margin-top:10px">INGREDIENTS:</div>
      <div style="font:400 5.2px/1.3 Arial;margin-top:2px;color:#3a3530">AQUA/WATER, GLYCERIN, COCAMIDOPROPYL HYDROXYSULTAINE, SODIUM LAUROYL SARCOSINATE, NIACINAMIDE, PEG-6 CAPRYLIC/CAPRIC GLYCERIDES, PROPYLENE GLYCOL, CERAMIDE NP, CERAMIDE AP, CERAMIDE EOP, CARBOMER, SODIUM CHLORIDE, CHOLESTEROL, PHENOXYETHANOL, DISODIUM EDTA, HYALURONIC ACID, CITRIC ACID, PHYTOSPHINGOSINE, XANTHAN GUM, ETHYLHEXYLGLYCERIN.</div>
      <div style="position:absolute;left:10px;top:192px;width:123px;height:62px;background:#fff;padding:4px 5px 0">
        <svg viewBox="0 0 128 46" width="113" height="44" preserveAspectRatio="none">${BARS}</svg>
        <div style="font:400 7.4px 'JetBrains Mono';letter-spacing:1.4px;text-align:center;margin-top:0">3 606000 537400</div></div>
    </div>`;
  // top-down camera view: same marble counter as the scene, tube lying on it with a soft shadow
  const tubeImg = `<img src="ugc/feed-tube.jpg" style="position:absolute;left:${-117 * 1.191}px;top:${-180 * 1.191}px;width:${752 * 1.191}px;height:${1344 * 1.191}px">`;
  const feed = `<div style="position:absolute;inset:-20px;transform:translate(${jx}px,${jy}px) scale(${zoom});transform-origin:216px 561px;filter:blur(${blur}px)">
      <img src="ugc/marble-src.jpg" style="position:absolute;left:-1716px;top:-1871px;width:${752 * 3.1}px;height:${1344 * 3.1}px;filter:blur(1.4px) brightness(1.03)">
      <div style="position:absolute;left:20px;top:20px;width:393px;height:852px;transform:rotate(-4deg);transform-origin:196px 541px;filter:drop-shadow(12px 20px 16px rgba(70,45,25,.38))">
        <div style="position:absolute;inset:0;clip-path:polygon(41px 124px,343px 124px,292px 742px,292px 880px,119px 880px,119px 742px)">${tubeImg}</div>
        ${label}
      </div></div>`;
  const corners = ['top:0;left:0;border-width:3.5px 0 0 3.5px;border-radius:22px 0 0 0','top:0;right:0;border-width:3.5px 3.5px 0 0;border-radius:0 22px 0 0','bottom:0;left:0;border-width:0 0 3.5px 3.5px;border-radius:0 0 0 22px','bottom:0;right:0;border-width:0 3.5px 3.5px 0;border-radius:0 0 22px 0']
    .map(s => `<i style="position:absolute;width:30px;height:30px;border:solid ${L > .9 ? '#F3D9CF' : '#fff'};${s}"></i>`).join('');
  const line = L < .05 ? `<div style="position:absolute;left:14px;right:14px;top:${50 + 42 * Math.sin(st.th * 3.2)}%;height:3px;border-radius:3px;background:#E7B8A6;box-shadow:0 0 18px 6px rgba(163,88,72,.55)"></div>` : '';
  let sheet = '';
  if (st.sheet) {
    const one = st.sheet === 1;
    sheet = `<div style="position:absolute;left:0;right:0;bottom:0;transform:translateY(${(1 - eo(st.sheetK)) * 100}%);background:var(--cream);border-radius:28px 28px 0 0;padding:14px 22px 40px;z-index:40;box-shadow:0 -10px 30px rgba(0,0,0,.25)">
      <div style="width:38px;height:5px;border-radius:9px;background:var(--line);margin:0 auto 16px"></div>
      <div style="display:flex;gap:12px;align-items:center">${one ? `<div style="width:44px;height:44px;border-radius:12px;background:var(--chip);display:flex;align-items:center;justify-content:center;color:var(--mu);font-size:20px">${ic('kb')}</div>` : mk('ProductPump.png', '#D6E0EA', 44)}
        <div><div style="font:600 18px 'DM Sans'">${one ? 'Looking up 3606000537400' : 'CeraVe Foaming Facial Cleanser'}</div><div style="font:400 12px 'JetBrains Mono';color:var(--mu);margin-top:2px">${one ? '3 606000 537400 · searching' : '3 606000 537400 · found'}</div></div></div>
      <div class="card" style="margin-top:16px;display:flex;gap:12px;align-items:center"><div style="width:22px;height:22px;border-radius:50%;border:2.5px solid var(--line);border-top-color:var(--p);transform:rotate(${st.th * 400}deg);flex:none"></div>
        <div><div style="font:600 15.5px 'DM Sans'">${one ? 'Checking product databases…' : 'Reading 24 ingredients…'}</div><div style="font-size:13px;color:var(--mu);margin-top:2px">${one ? 'Cache, Open Beauty Facts, then AI search' : 'Auto-confirmed — no extra taps'}</div></div></div>
    </div>`;
  }
  return `<div style="position:absolute;inset:0;background:#222">${feed}</div>
  <div style="position:absolute;inset:0;background:linear-gradient(rgba(0,0,0,.42),rgba(0,0,0,0) 22%,rgba(0,0,0,0) 72%,rgba(0,0,0,.5))"></div>
  <div style="position:relative">${sbar(true)}</div>
  <div style="position:absolute;top:62px;left:16px;width:44px;height:44px;border-radius:50%;background:rgba(255,255,255,.2);display:flex;align-items:center;justify-content:center;color:#fff;font-size:18px">${ic('x','stroke-width:2.4')}</div>
  <div style="position:absolute;top:62px;right:16px;width:44px;height:44px;border-radius:50%;background:rgba(255,255,255,.2);display:flex;align-items:center;justify-content:center;color:#fff;font-size:18px">${ic('bolt')}</div>
  <div style="position:absolute;left:${b[0]}px;top:${b[1]}px;width:${b[2]}px;height:${b[3]}px;transform:scale(${L > .9 && L < 1 ? 1.04 : 1})">${corners}${line}</div>
  <div style="position:absolute;top:${b[1] + b[3] + 18}px;left:0;right:0;text-align:center"><span style="display:inline-block;background:rgba(0,0,0,.55);color:#fff;font:500 15px 'DM Sans';padding:12px 18px;border-radius:99px">${hint}</span></div>
  <div style="position:absolute;left:22px;right:22px;bottom:56px;display:flex;gap:10px">${[['kb','Type it'],['doc','Photo of ingredients']].map(p => `<div style="flex:1;height:52px;border-radius:14px;background:rgba(255,255,255,.18);border:1px solid rgba(255,255,255,.25);color:#fff;display:flex;align-items:center;justify-content:center;gap:7px;font:600 14.5px 'DM Sans';white-space:nowrap">${ic(p[0],'font-size:16px')}${p[1]}</div>`).join('')}</div>
  ${sheet}`;
}
SCREENS.scanreal = scanRealScreen;
