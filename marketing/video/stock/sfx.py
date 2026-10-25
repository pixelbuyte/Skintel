"""Sound effects for the skits, synthesized so there is nothing to license and every sound is known:
a glassy receive "tink", a rising send whoosh-pop, soft keyboard ticks, a camera shutter, a chime,
a transition whoosh and an end-card pop. sfx.make(dir) writes them as 48 kHz WAVs."""
import wave
import numpy as np

SR = 48000

def _t(d):
    return np.arange(int(SR * d)) / SR

def _noise(d, seed):
    return np.random.default_rng(seed).uniform(-1, 1, int(SR * d))

def _bandsweep(x, f0, f1, q=4.0):
    """Resonant band-pass whose centre glides from f0 to f1 (a state-variable filter)."""
    out, lo, bp = np.zeros_like(x), 0.0, 0.0
    fc = np.geomspace(f0, f1, len(x))
    for i, s in enumerate(x):
        f = 2 * np.sin(np.pi * fc[i] / SR)
        lo += f * bp
        hi = s - lo - bp / q
        bp += f * hi
        out[i] = bp
    return out / (np.abs(out).max() + 1e-9)

def recv():
    t = _t(0.45)
    env = np.minimum(1, t / 0.004) * np.exp(-t * 11)
    return 0.42 * env * (np.sin(2 * np.pi * 1760 * t) + 0.55 * np.sin(2 * np.pi * 2637 * t) + 0.25 * np.sin(2 * np.pi * 3520 * t) * np.exp(-t * 20))

def send():
    d = 0.22
    t = _t(d)
    whoosh = _bandsweep(_noise(d, 1), 700, 4200) * np.sin(np.pi * t / d) ** 2 * 0.35
    pop_t = _t(0.06)
    pop = 0.35 * np.sin(2 * np.pi * (900 + 600 * np.exp(-pop_t * 60)) * pop_t) * np.exp(-pop_t * 70)
    out = whoosh.copy()
    out[-len(pop):] += pop
    return out

def keys(n=7, gap=0.105, seed=3):
    rng = np.random.default_rng(seed)
    out = np.zeros(int(SR * (n * gap + 0.1)))
    for k in range(n):
        at = int(SR * (k * gap + rng.uniform(-0.02, 0.02) + 0.02))
        tick_t = _t(0.035)
        click = _noise(0.035, seed + k) * np.exp(-tick_t * 260) * 0.5
        body = 0.18 * np.sin(2 * np.pi * rng.uniform(180, 240) * tick_t) * np.exp(-tick_t * 90)
        out[at:at + len(tick_t)] += (click - np.convolve(click, np.ones(6) / 6, 'same')) * 1.6 + body
    return out

def click():
    out = np.zeros(int(SR * 0.16))
    for at, amp in ((0, 0.8), (0.07, 0.5)):
        t = _t(0.05)
        i = int(SR * at)
        out[i:i + len(t)] += amp * _noise(0.05, int(at * 100)) * np.exp(-t * 120)
    return out

def sparkle():
    t = _t(0.9)
    out = np.zeros_like(t)
    for k, f in enumerate((1568, 2093, 2637, 3136)):
        d = k * 0.06
        tt = np.clip(t - d, 0, None)
        out += (t >= d) * 0.16 * np.sin(2 * np.pi * f * tt) * np.exp(-tt * 6)
    return out

def whoosh():
    d = 0.5
    t = _t(d)
    return _bandsweep(_noise(d, 9), 300, 2800, q=2.5) * np.sin(np.pi * t / d) ** 1.5 * 0.45

def pop():
    t = _t(0.18)
    return 0.5 * np.sin(2 * np.pi * (300 + 500 * np.exp(-t * 35)) * t) * np.exp(-t * 22)

SOUNDS = {'recv': recv, 'send': send, 'keys': keys, 'click': click, 'sparkle': sparkle, 'whoosh': whoosh, 'pop': pop}

# Meme-style stings, original synthesis in the style of the genre (nothing copied from real clips).
def _reverb(x, delays=(0.031, 0.047, 0.071, 0.109), fb=0.45):
    out = x.copy()
    for d in delays:
        n = int(SR * d)
        tail = np.zeros(len(x) + n * 6)
        tail[:len(x)] = x
        for k in range(1, 6):
            tail[n * k:n * k + len(x)] += x * fb ** k
        out = out + 0.25 * tail[:len(x)]
    return out

def boom():
    """Vine-boom style: a huge distorted sub drop with a room tail."""
    t = _t(1.6)
    f = 38 + 30 * np.exp(-t * 9)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2)
    hit = _noise(0.04, 21) * np.exp(-_t(0.04) * 90) * 0.6
    x = np.tanh(3.2 * sub) * 0.75
    x[:len(hit)] += hit
    return _reverb(x) * 0.45

def scratch():
    """Record scratch: band-passed noise dragged forward and back."""
    d = 0.55
    t = _t(d)
    n = _noise(d, 33)
    wob = np.sin(2 * np.pi * 7 * t)
    out, lo, bp = np.zeros_like(n), 0.0, 0.0
    for i, sm in enumerate(n):
        fc = 900 + 2600 * (0.5 + 0.5 * wob[i])
        f = 2 * np.sin(np.pi * fc / SR)
        lo += f * bp; hi = sm - lo - bp / 6; bp += f * hi
        out[i] = bp
    gate = (np.abs(wob) > 0.25) * np.exp(-t * 2.5)
    return 0.6 * out / np.abs(out).max() * gate

def _brass(freq, d, vib=0.0, seed=0):
    t = _t(d)
    ph = 2 * np.pi * np.cumsum(freq * (1 + vib * np.sin(2 * np.pi * 5.5 * t))) / SR
    saw = sum(np.sin(k * ph) / k for k in range(1, 12))
    env = np.minimum(1, t / 0.03) * np.minimum(1, (d - t) / 0.08)
    return saw * env

def wahwah():
    """Sad trombone: four sliding notes down, the last one wobbling."""
    notes = [(233.1, 0.32), (220.0, 0.32), (207.7, 0.32), (196.0, 1.0)]
    parts = [_brass(f, d, vib=0.03 if i == 3 else 0.004) * (0.9 if i < 3 else 1) for i, (f, d) in enumerate(notes)]
    x = np.concatenate(parts)
    k = np.ones(40) / 40
    return 0.22 * np.convolve(x, k, 'same')

def dun():
    """Dramatic sting: dun, dun, DUUUN (minor chords, the last one low and long, with a timpani)."""
    def chord(root, d):
        return sum(_brass(root * r, d) for r in (1, 1.189, 1.498)) / 3
    gap = np.zeros(int(SR * 0.07))
    x = np.concatenate([chord(261.6, 0.22), gap, chord(261.6, 0.22), gap, chord(196.0, 1.3)])
    timp_t = _t(1.3)
    timp = np.sin(2 * np.pi * 65 * timp_t) * np.exp(-timp_t * 3) * 0.8
    x[-len(timp):] += timp
    return _reverb(0.3 * np.convolve(x, np.ones(25) / 25, 'same'))

def ding():
    """Quiz-show correct: two bright bell notes rising."""
    out = np.zeros(int(SR * 1.0))
    for at, f in ((0, 1046.5), (0.12, 1318.5)):
        t = _t(0.85)
        bell = (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 8)) * np.exp(-t * 4.5)
        i = int(SR * at)
        out[i:i + len(t)] += 0.3 * bell
    return out

SOUNDS.update({'boom': boom, 'scratch': scratch, 'wahwah': wahwah, 'dun': dun, 'ding': ding})

def make(directory):
    directory.mkdir(parents=True, exist_ok=True)
    paths = {}
    for name, fn in SOUNDS.items():
        p = directory / f'{name}.wav'
        if not p.exists():
            x = np.clip(fn(), -1, 1)
            with wave.open(str(p), 'wb') as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
                w.writeframes((x * 32767).astype(np.int16).tobytes())
        paths[name] = p
    return paths
