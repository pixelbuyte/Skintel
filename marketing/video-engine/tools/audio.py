# Builds an ad soundtrack: soft beat bed + SFX at event times. Usage: audio.py events.json out.wav
import json, sys, wave
import numpy as np
SR = 44100
rng = np.random.default_rng(3)

def env(n, a, d):
    e = np.ones(n); a = max(1, int(a * SR)); e[:a] = np.linspace(0, 1, a)
    e *= np.exp(-np.arange(n) / (d * SR)); return e

def lp(x, k):  # cheap one-pole lowpass, k in (0,1)
    y = np.empty_like(x); acc = 0.0
    for i, v in enumerate(x): acc += k * (v - acc); y[i] = acc
    return y

def whoosh(dur=.45):
    n = int(dur * SR); t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # sweep a band by mixing two lowpasses with moving cutoff
    k = np.interp(t, [0, dur * .6, dur], [.02, .35, .05])
    y = np.empty(n); acc = 0.0
    for i in range(n): acc += k[i] * (noise[i] - acc); y[i] = acc
    y = y - lp(y, .02)
    shape = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return .9 * y * shape / (np.abs(y).max() + 1e-9)

def click():
    n = int(.05 * SR); t = np.arange(n) / SR
    return .5 * np.sin(2 * np.pi * 2400 * t) * env(n, .0005, .006) + .3 * rng.standard_normal(n) * env(n, .0002, .002)

def pop():
    n = int(.12 * SR); t = np.arange(n) / SR
    f = np.interp(t, [0, .12], [900, 380])
    return .55 * np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, .001, .03)

def hit():
    n = int(1.4 * SR); t = np.arange(n) / SR
    f = np.interp(t, [0, .08, 1.4], [120, 52, 40])
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, .002, .45)
    crack = lp(rng.standard_normal(n), .25) * env(n, .001, .05)
    return .95 * sub + .35 * crack

def riser(dur=1.6):
    n = int(dur * SR); t = np.arange(n) / SR
    f = np.interp(t, [0, dur], [200, 1400])
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * .15
    noise = (rng.standard_normal(n) - lp(rng.standard_normal(n), .05)) * .25
    return (tone + noise) * (t / dur) ** 2

def chime():
    n = int(1.2 * SR); t = np.arange(n) / SR
    y = sum(a * np.sin(2 * np.pi * f * t) for f, a in [(1318.5, .5), (1975.5, .3), (2637, .15)])
    return .35 * y * env(n, .002, .35)

def key():
    n = int(.03 * SR)
    x = rng.standard_normal(n); x = x - lp(x, .25)
    return .45 * x * env(n, .0003, .006)

def swish():
    return whoosh(.28) * .8

def reverb(x, decay=.35, taps=((.029,.6),(.047,.45),(.071,.35),(.11,.25),(.17,.15))):
    y = x.copy()
    for d, g in taps:
        k = int(d * SR); y[k:] += x[:-k] * g * decay * 2
    return y

def boom():  # vine-boom-style: big low thud, slightly overdriven, with a tail
    n = int(1.6 * SR); t = np.arange(n) / SR
    f = np.interp(t, [0, .04, .3, 1.6], [180, 62, 44, 38])
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, .001, .55)
    x = np.tanh(x * 3.2) * .9
    x += lp(rng.standard_normal(n), .08) * env(n, .001, .08) * .5
    return reverb(x) * .9

def scratch():  # record scratch: noisy pitch swoop forward and back
    n = int(.55 * SR); t = np.arange(n) / SR
    f = np.interp(t, [0, .12, .25, .4, .55], [300, 1800, 400, 1500, 200])
    tone = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * .25
    noise = rng.standard_normal(n); noise = noise - lp(noise, .12)
    y = lp(tone + noise * .5, .35) * np.interp(t, [0, .03, .5, .55], [0, 1, .8, 0])
    return y * 1.4

def dun():  # "dun dun duuun": three brassy notes going down
    out = []
    for f0, d in [(293.7, .28), (277.2, .28), (233.1, 1.1)]:
        n = int(d * SR); t = np.arange(n) / SR
        saw = sum(np.sin(2 * np.pi * f0 * k * t) / k for k in range(1, 9))
        saw += .5 * sum(np.sin(2 * np.pi * f0 / 2 * k * t) / k for k in range(1, 6))
        out.append(lp(saw, .18) * env(n, .015, d * .9) * .5); out.append(np.zeros(int(.04 * SR)))
    return reverb(np.concatenate(out))

def boing():  # cartoon spring
    n = int(.5 * SR); t = np.arange(n) / SR
    f = np.interp(t, [0, .5], [520, 180]) * (1 + .12 * np.sin(2 * np.pi * 22 * t))
    return .6 * np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, .002, .22)

def errbuzz():  # error buzz: two low square blips
    out = []
    for f0 in (220, 165):
        n = int(.16 * SR); t = np.arange(n) / SR
        out.append(lp(np.sign(np.sin(2 * np.pi * f0 * t)), .3) * .35 * env(n, .002, .2)); out.append(np.zeros(int(.04 * SR)))
    return np.concatenate(out)

def ding():  # bright "correct" ding
    n = int(1.0 * SR); t = np.arange(n) / SR
    y = .5 * np.sin(2 * np.pi * 1760 * t) + .3 * np.sin(2 * np.pi * 2637 * t) + .15 * np.sin(2 * np.pi * 3520 * t)
    return y * env(n, .002, .25) * .7

def ambience(dur):  # non-musical room tone: warm brown noise + soft air, slow natural swell, stereo-ish
    n = int(dur * SR); t = np.arange(n) / SR
    w = rng.standard_normal(n)
    brown = np.cumsum(w); brown -= lp(brown, .0005); brown /= (np.abs(brown).max() + 1e-9)
    air = lp(w, .15) - lp(w, .02); air /= (np.abs(air).max() + 1e-9)
    swell = .75 + .25 * np.sin(2 * np.pi * t / 7.3) * np.sin(2 * np.pi * t / 3.1 + 1)
    fade = np.minimum(1, np.minimum(t / .4, (dur - t) / .6))
    return (brown * .55 + air * .22) * swell * fade

def bed(dur, bpm=100):
    n = int(dur * SR); t = np.arange(n) / SR; out = np.zeros(n); beat = 60 / bpm
    # kick on 1 and 3 of each bar, hat on offbeats, warm pad (Fmaj7 -> Am7 -> Dm9 -> Cmaj7)
    for i in range(int(dur / beat) + 1):
        s = int(i * beat * SR)
        if s >= n: break
        if i % 2 == 0:
            k = int(.35 * SR); kt = np.arange(k) / SR; f = np.interp(kt, [0, .05, .35], [140, 55, 45])
            kick = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(k, .002, .12) * .55
            out[s:s + k] += kick[:max(0, min(k, n - s))]
        h = int(.05 * SR); hs = s + int(beat / 2 * SR)
        if hs + h < n: out[hs:hs + h] += (rng.standard_normal(h) - lp(rng.standard_normal(h), .3)) * env(h, .0005, .012) * .08
    chords = [[174.6, 220, 261.6, 329.6], [220, 261.6, 329.6, 392], [146.8, 174.6, 220, 329.6], [130.8, 164.8, 196, 246.9]]
    bar = 4 * beat
    for b in range(int(dur / bar) + 1):
        s = int(b * bar * SR); e = min(n, int((b + 1) * bar * SR))
        if s >= n: break
        tt = np.arange(e - s) / SR
        pad = sum(np.sin(2 * np.pi * f * tt) + .3 * np.sin(2 * np.pi * 2 * f * tt + .5) for f in chords[b % 4])
        fade = np.minimum(1, np.minimum(tt / .3, (bar - tt) / .3))
        out[s:e] += pad * fade * .035
    return out

def build(ev, out):
    dur = ev['dur']; n = int(dur * SR) + SR
    mix = np.zeros(n)
    b = bed(dur + 1, ev.get('bpm', 100)) if ev.get('music', False) else np.pad(ambience(dur), (0, n - int(dur * SR))) * ev.get('amb', .28)
    gain = np.ones(n)
    for (a, z) in ev.get('duck', []):  # drop the bed for impact moments
        gain[int(a * SR):int(z * SR)] = .25
    for (t0, path, vol, d) in ev.get('vo', []):  # duck the bed under the voice
        gain[int(t0 * SR):int((t0 + d + .15) * SR)] = np.minimum(gain[int(t0 * SR):int((t0 + d + .15) * SR)], .4)
    mix[:len(b)] += b * gain[:len(b)] * 1.25
    import soundfile as sf
    for (t0, path, vol, d) in ev.get('vo', []):
        v, sr = sf.read(path)
        if v.ndim > 1: v = v.mean(1)
        v = np.interp(np.arange(int(len(v) * SR / sr)) * sr / SR, np.arange(len(v)), v)
        v = v / (np.abs(v).max() + 1e-9) * .82
        i = int(t0 * SR); m = min(len(v), n - i)
        if m > 0: mix[i:i + m] += v[:m] * vol
    fx = {'whoosh': whoosh, 'click': click, 'pop': pop, 'hit': hit, 'riser': riser, 'chime': chime, 'key': key, 'swish': swish, 'boom': boom, 'scratch': scratch, 'dun': dun, 'boing': boing, 'error': errbuzz, 'ding': ding}
    cache = {}
    for t0, name, vol in ev['fx']:
        if name not in cache: cache[name] = fx[name]()
        s = cache[name]; i = int(t0 * SR)
        if name == 'riser': i = max(0, i - len(s))  # riser ends at t0
        m = min(len(s), n - i)
        if m > 0: mix[i:i + m] += s[:m] * vol
    fade = int(.6 * SR); mix[int(dur * SR) - fade:int(dur * SR)] *= np.linspace(1, 0, fade); mix[int(dur * SR):] = 0
    mix = mix[:int(dur * SR)]
    mix = np.tanh(mix * 1.1) * .9
    pcm = (mix * 32767).astype(np.int16)
    st = np.stack([pcm, pcm], 1).tobytes()
    with wave.open(out, 'wb') as w: w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(st)

if __name__ == '__main__':
    build(json.load(open(sys.argv[1])), sys.argv[2])
