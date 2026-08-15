/* Deterministic timeline engine — every visual state is a pure function of t (seconds).
   No CSS animations, no requestAnimationFrame: the renderer seeks to exact frame times. */

const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const lerp = (a, b, p) => a + (b - a) * p;

/** local progress 0..1 across [start,end] */
const seg = (t, start, end) => clamp((t - start) / (end - start), 0, 1);

const easeOut     = p => 1 - Math.pow(1 - p, 3);
const easeOutQuint= p => 1 - Math.pow(1 - p, 5);
const easeInOut   = p => (p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2);
/** Emil-style overshoot used across the Skintel UI */
const easeEmil    = p => 1 - Math.pow(1 - p, 4);

/** Split element text into per-word spans so words can stagger in. */
function splitWords(el) {
  if (el.dataset.split) return [...el.querySelectorAll('.w')];
  const html = el.innerHTML;
  // preserve inline tags by splitting on spaces at the text level only
  const tmp = document.createElement('div');
  tmp.innerHTML = html;
  const out = [];
  function walk(node, into) {
    node.childNodes.forEach(child => {
      if (child.nodeType === 3) {
        child.textContent.split(/(\s+)/).forEach(tok => {
          if (!tok) return;
          if (/^\s+$/.test(tok)) { into.appendChild(document.createTextNode(tok)); return; }
          const s = document.createElement('span');
          s.className = 'w';
          s.textContent = tok;
          into.appendChild(s);
          out.push(s);
        });
      } else if (child.nodeType === 1) {
        const c = child.cloneNode(false);
        into.appendChild(c);
        walk(child, c);
      }
    });
  }
  const frag = document.createElement('div');
  walk(tmp, frag);
  el.innerHTML = frag.innerHTML;
  el.dataset.split = '1';
  return [...el.querySelectorAll('.w')];
}

/** Stagger a word reveal: each word rises + fades over `dur`, offset by `step`. */
function revealWords(el, t, start, { dur = 0.62, step = 0.055, rise = 46, blur = false } = {}) {
  const words = splitWords(el);
  words.forEach((w, i) => {
    const p = easeOutQuint(seg(t, start + i * step, start + i * step + dur));
    w.style.opacity = p;
    w.style.transform = `translateY(${(1 - p) * rise}px)`;
    if (blur) w.style.filter = p < 1 ? `blur(${(1 - p) * 9}px)` : 'none';
  });
  return start + words.length * step + dur;
}

/** Fade + rise a whole element. */
function riseIn(el, t, start, { dur = 0.72, rise = 40, from = 0.985 } = {}) {
  const p = easeOutQuint(seg(t, start, start + dur));
  el.style.opacity = p;
  el.style.transform = `translateY(${(1 - p) * rise}px) scale(${lerp(from, 1, p)})`;
  return p;
}

/** Scene cross-fade wrapper: returns visibility 0..1 with soft in/out. */
function sceneAlpha(t, inAt, outAt, fade = 0.42) {
  const a = seg(t, inAt, inAt + fade);
  const b = 1 - seg(t, outAt - fade, outAt);
  return Math.min(easeInOut(a), easeInOut(b));
}

/** Apply scene alpha + a gentle drift so cuts never feel static. */
function applyScene(el, t, inAt, outAt, { drift = 26, fade = 0.42, scale = 0.012 } = {}) {
  const a = sceneAlpha(t, inAt, outAt, fade);
  el.style.opacity = a;
  el.style.display = a <= 0.001 ? 'none' : 'flex';
  const life = seg(t, inAt, outAt);
  el.style.transform = `translateY(${lerp(drift, -drift, life)}px) scale(${1 + scale * life})`;
  return a;
}

/** Slow continuous push-in for phone mockups (Ken Burns). */
function kenBurns(t, inAt, outAt, from = 1.0, to = 1.07) {
  return lerp(from, to, easeInOut(seg(t, inAt, outAt)));
}

window.__E = {
  clamp, lerp, seg, easeOut, easeOutQuint, easeInOut, easeEmil,
  splitWords, revealWords, riseIn, sceneAlpha, applyScene, kenBurns,
};
