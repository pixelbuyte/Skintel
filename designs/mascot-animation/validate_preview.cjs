// Checks preview.html's drawing code without a browser: every action draws valid SVG with
// finite numbers, Reduce Motion poses are stable, walking alternates legs and travel turns.
// Run: node validate_preview.cjs
const fs = require('fs'), vm = require('vm'), assert = require('assert');
const html = fs.readFileSync(__dirname + '/preview.html', 'utf8');
const source = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const sandbox = {};
vm.createContext(sandbox);
vm.runInContext(source + '\nthis.api = {ACTIONS, pose, motion, mascotSVG};', sandbox);
const {ACTIONS, pose, motion, mascotSVG} = sandbox.api;

assert.equal(ACTIONS.length, 8);
for (const [action] of ACTIONS) {
  for (let i = 0; i < 600; i++) {
    const svg = mascotSVG(600, 400, i / 30, action, {travels: true});
    assert(!/NaN|undefined|Infinity/.test(svg), `${action} at frame ${i}`);
  }
  assert.equal(mascotSVG(300, 360, 0, action, {still: true}), mascotSVG(300, 360, 42.7, action, {still: true}), `${action} still pose`);
}
const w = pose('walk', 0.2, false);
assert(w.leftLeg === -w.rightLeg && Math.abs(w.leftLeg) > 10, 'walk alternates');
let turned = false, prev = motion.placement(0, 200, 0.5, true, false);
for (let i = 1; i < 3000; i++) {
  const p = motion.placement(i / 30, 200, 0.5, true, false);
  assert(p.x >= 0 && p.x <= 200 && Math.abs(p.x - prev.x) < 2);
  if (p.mirrored !== prev.mirrored) turned = true;
  prev = p;
}
assert(turned, 'travel turns at the edges');
console.log('PASS: 8 actions draw finite SVG, stable Reduce Motion poses, alternating walk, travel turns.');
