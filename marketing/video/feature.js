/* Shared beats for the feature reels (f-*.html): caption above the phone, typing, tap ripples,
   the keyword end card. Deterministic like engine.js: every state is a function of t. */
(() => {
const E = window.__E;
const $ = id => document.getElementById(id);
const ART = "../../ios/Skintel/Skintel/Resources/Assets.xcassets";
const mascot = `${ART}/Mascot.imageset/Mascot.png`;
/* ?mode=body: the same demo as the body of a reaction-hook video (HOOKS.md). No captions, the
   phone fills the frame with a slight hand-held sway, so a hook clip can be cut in front of it. */
/* ?mode=screen: only the app screen (886×1918, no phone, no captions), to be mapped onto a real
   phone in stock footage by stock/composite.py. */
const MODE = new URLSearchParams(location.search).get("mode");
const SCREEN = MODE === "screen";
const BODY = MODE === "body" || SCREEN;
if (SCREEN) document.documentElement.classList.add("screen-mode");
if (BODY) {
  document.documentElement.classList.add("body-mode");
  // The tap ripple rides inside the phone, so it follows the phone's transform.
  const dot = $("tapdot"); if (dot) $("phone").appendChild(dot);
}

/** Resolve ART/ placeholders in src attributes. */
function art() {
  document.querySelectorAll("[src^='ART/']").forEach(i => { i.src = i.getAttribute("src").replace("ART", ART); });
}

/** Phone rises in at the start, then optional push-ins so app text reads at feed size.
    zooms: [[start, end, scale, lift]]: grows from the phone's top edge (so it never covers the
    caption); lift (stage px) slides it up for content further down the screen. */
function phoneIn(t, at = 0.15, zooms = []) {
  if (SCREEN) {
    const ph = $("phone");
    ph.style.transformOrigin = "0 0";
    ph.style.transform = `scale(${886 / 647})`;
    return;
  }
  if (BODY) {
    const ph = $("phone");
    const sway = `translate(${Math.sin(t * 1.3) * 6}px, ${Math.cos(t * 1.1) * 5}px) rotate(${Math.sin(t * 0.9) * 0.7}deg)`;
    ph.style.transformOrigin = "50% 0";
    ph.style.transform = `translateY(${(1920 - 1437 * 1.25) / 2 - 450}px) ${sway} scale(1.25)`;
    return;
  }
  const p = E.easeEmil(E.seg(t, at, at + 0.8));
  let s = 1, lift = 0;
  for (const [a, b, sc, y] of zooms) {
    const k = E.easeInOut(E.seg(t, a, a + 0.7)) * (1 - E.easeInOut(E.seg(t, b - 0.5, b)));
    if (k > 0) { s = 1 + (sc - 1) * k; lift = y * k; }
  }
  const ph = $("phone");
  ph.style.transformOrigin = "50% 0";
  ph.style.transform = `translateY(${(1 - p) * 700 - lift}px) scale(${s})`;
}

/** Captions: [[start, eyebrow, html], …]; each replaces the last with a quick cross-fade. */
function captions(t, list) {
  let cur = -1;
  list.forEach((c, i) => { if (t >= c[0]) cur = i; });
  const cap = $("cap");
  if (cur < 0 || BODY) { cap.style.opacity = 0; return; }
  const [start, eyebrow, html] = list[cur];
  if (cap.dataset.i !== String(cur)) {
    cap.dataset.i = String(cur);
    cap.innerHTML = `<div class="e">${eyebrow}</div><div class="h">${html}</div>`;
  }
  const next = list[cur + 1] ? list[cur + 1][0] : Infinity;
  const fade = Math.min(E.seg(t, start, start + 0.3), 1 - E.seg(t, next - 0.2, next));
  cap.style.opacity = fade;
  E.revealWords(cap.querySelector(".h"), t, start, { step: 0.045, dur: 0.45, rise: 30 });
}

/** Typed text with a blinking caret. Returns true once fully typed. */
function type(el, text, t, start, cps = 18, caret = true) {
  const n = Math.max(0, Math.min(text.length, Math.floor((t - start) * cps)));
  const blink = Math.floor(t * 2.2) % 2 === 0;
  el.innerHTML = (t < start ? "" : escapeHtml(text.slice(0, n))) + (caret && t >= start - 0.6 && (n < text.length || blink) ? '<span class="caret"></span>' : "");
  return n >= text.length;
}
function escapeHtml(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;"); }

/** Fade/rise an element in at `at` (and optionally out at `out`). */
function appear(el, t, at, out = Infinity, rise = 14) {
  const gone = Number.isFinite(out) ? E.seg(t, out, out + 0.25) : 0;  // seg(Infinity) is NaN
  const p = E.easeEmil(E.seg(t, at, at + 0.35)) * (1 - gone);
  el.style.opacity = p;
  el.style.transform = `translateY(${(1 - p) * rise}px)`;
  el.style.visibility = p <= 0.001 ? "hidden" : "visible";
  return p;
}

/** Three bouncing dots while Skintel writes. */
function dots(el, t, at, out) {
  const on = t >= at && t < out;
  el.style.display = on ? "flex" : "none";
  if (on) [...el.children].forEach((d, i) => { d.style.opacity = 0.25 + 0.6 * Math.max(0, Math.sin((t - at) * 7 - i * 0.9)); });
}

/** Tap ripple at screen point (x, y) in pt. */
function tap(t, at, x, y) {
  const el = $("tapdot");
  const p = E.seg(t, at - 0.15, at + 0.35);
  if (p <= 0 || p >= 1) return false;
  const s = 1.659;
  const ox = SCREEN ? 0 : BODY ? 18 : 198 + 18, oy = SCREEN ? 0 : BODY ? 18 : 450 + 18;  // phone-local when inside the phone
  el.style.left = `${ox + x * s}px`; el.style.top = `${oy + y * s}px`;
  el.style.opacity = p < 0.3 ? p / 0.3 : 1 - (p - 0.3) / 0.7;
  el.style.transform = `scale(${0.6 + p * 0.9})`;
  return true;
}
function taps(t, list) { $("tapdot").style.opacity = 0; for (const [at, x, y] of list) if (tap(t, at, x, y)) break; }

/** The keyword end card (same as the other reels). */
function ctaHTML(line2) {
  return `<div class="cta" id="cta"><img class="m" id="ctam" src="${mascot}">
    <div class="l1" id="ctal1">Comment</div><div><span class="kw" id="ctakw">SKINSTEL</span></div>
    <div class="l2" id="ctal2">${line2}</div><div class="h" id="ctah">@skins_tel</div></div>`;
}
function cta(t, start) {
  const ca = E.seg(t, start, start + 0.4);
  $("cta").style.display = ca > 0 ? "flex" : "none";
  $("cta").style.opacity = E.easeInOut(ca);
  $("main").style.opacity = 1 - E.easeInOut(ca);
  if (ca <= 0) return;
  const bob = Math.sin((t - start) * 3.2) * 10;
  const m = E.easeEmil(E.seg(t, start + 0.1, start + 0.6));
  $("ctam").style.transform = `translateY(${bob + (1 - m) * 60}px) scale(${E.lerp(0.7, 1, m)})`;
  $("ctam").style.opacity = m;
  E.riseIn($("ctal1"), t, start + 0.35, { rise: 30 });
  const k = E.easeEmil(E.seg(t, start + 0.6, start + 1.0));
  $("ctakw").style.transform = `scale(${E.lerp(0.6, 1, k)})`; $("ctakw").style.opacity = k;
  E.riseIn($("ctal2"), t, start + 1.1, { rise: 24 });
  E.riseIn($("ctah"), t, start + 1.4, { rise: 20 });
}

const ctaCSS = `
  .cta { position: absolute; inset: 0; display: none; flex-direction: column; align-items: center; justify-content: center; text-align: center; padding: 0 90px; z-index: 40; }
  .cta .m { width: 300px; height: 300px; object-fit: contain; }
  .cta .l1 { font-family: 'Instrument Serif', serif; font-size: 120px; line-height: 1; margin-top: 30px; }
  .cta .kw { display: inline-block; margin-top: 26px; background: #A35848; color: #FFFEFA; font-weight: 700; font-size: 104px; letter-spacing: .04em; padding: 18px 56px 24px; border-radius: 999px; box-shadow: 0 24px 50px rgba(163,88,72,.4); }
  .cta .l2 { font-size: 46px; color: #6B6760; margin-top: 46px; line-height: 1.3; }
  .cta .h { font-size: 38px; color: #A35848; margin-top: 34px; font-weight: 700; letter-spacing: .02em; }`;
document.head.insertAdjacentHTML("beforeend", `<style>${ctaCSS}</style>`);

const STATUS = `<div class="status"><span>9:41</span><svg width="76" height="14" viewBox="0 0 190 40" fill="currentColor">
  <rect x="0" y="26" width="10" height="12" rx="3"/><rect x="15" y="19" width="10" height="19" rx="3"/><rect x="30" y="11" width="10" height="27" rx="3"/><rect x="45" y="3" width="10" height="35" rx="3"/>
  <path d="M88 36l-7-7a10 10 0 0 1 14 0zM73 21a21 21 0 0 1 30 0l-4 4a15 15 0 0 0-22 0zM65 13a32 32 0 0 1 46 0l-4 4a26 26 0 0 0-38 0z"/>
  <rect x="124" y="7" width="54" height="27" rx="8" fill="none" stroke="currentColor" stroke-width="3" opacity=".45"/><rect x="128" y="11" width="46" height="19" rx="5"/></svg></div>`;
const SPARK = `<svg width="14" height="14" viewBox="0 0 24 24" fill="#FFFEFA"><path d="M12 2l2.2 6.8L21 11l-6.8 2.2L12 20l-2.2-6.8L3 11l6.8-2.2z"/></svg>`;

window.F = { $, art, phoneIn, captions, type, appear, dots, tap, taps, cta, ctaHTML, STATUS, SPARK, ART };
})();
