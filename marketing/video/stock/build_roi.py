#!/usr/bin/env python3
"""Cinematic AI ads: AI B-roll (Seedance clips or animated stills) → a stretch of an app demo → the
Comment SKINSTEL end card, with a voiceover, a tension bed and sound effects.

    CHROME_PATH=... python3 stock/build_roi.py                  # all
    CHROME_PATH=... python3 stock/build_roi.py pov-scan         # one

Each ad writes out/roi-<name>.mp4 (voice + sound) and out/roi-<name>-silent.mp4 (captions only,
for a trending sound):
    1ofthese       "1 of these is breaking you out": a shelf where one bottle lights up red, a bottle
                   pulled from a lineup, a pinboard of red string → triggers
    pov-scan       "POV: you check if it'll break you out before you buy it": a store aisle, a phone at
                   the barcode → scan and its verdict
    pov-conflicts  "POV: 2 of your products have been fighting every night": two serums at the sink, two
                   drops swirling together → the routine check
    pov-ask        "POV: it's 1am and you still don't know what order these go in": products on the bed,
                   then lined up in morning sun → Ask Skintel plans the routine
Each ends on a comment prompt anyone can answer (a guess, their routine) before the end card asks
for SKINSTEL.

Footage in stock/cache/roi/ (gitignored), made in the ElevenLabs flow "Skinstel ROI ad": Seedance 2.5
clips (720p 9:16) and Nano Banana 2 stills (2K 9:16), no people's faces, unbranded products; voiceovers
from Roxie (eleven_v4); tick*.mp3 are ElevenLabs sound effects (ticking clock and sub drone, no
music). Captions come from roi.html (render-alpha.mjs roi <name>); keep its ADS times on SHOTS here.
"""
import math, re, subprocess, sys
from PIL import Image
import sfx
from build_stock import HERE, OUT, VIDEO, run

SRC = HERE / 'cache' / 'roi'
TMP = OUT / 'roi-tmp'
ENC = ['-c:v', 'libx264', '-preset', 'slow', '-crf', 18, '-pix_fmt', 'yuv420p']
AI = 'scale=1080:1920:flags=lanczos,unsharp=5:5:0.6,setsar=1'
FIT = 'scale=1080:1920,setsar=1'
VO_LUFS = -16
FLICKER = "eq=brightness='0.025*sin(2*PI*2.3*t)+0.015*sin(2*PI*7.1*t)':eval=frame"

def still(img, dur, z0, z1, c0=(0.5, 0.5), c1=None, shake=4, flicker=False):
    """A camera move over a still: zoom z0 → z1 about a centre (fractions of the image) drifting
    c0 → c1, with a little hand-held sway, optionally a lamp flicker."""
    return ('still', img, dur, z0, z1, c0, c1 or c0, shake, flicker)

def clip(src, ss, t, speed=1.0, vf=AI):
    return ('clip', src, ss, t, speed, vf)

def demo(name, ss, t):
    return clip(OUT / f'skintel-f-{name}.mp4', ss, t, 1.0, FIT)

# shots: in order; vo: (take, start, end, where it plays); hits: (time, sound, gain); caps_end: where
# the end card starts (captions and the bed stop there).
ADS = {
    '1ofthese': dict(
        shots=[
            clip(SRC / 'shelf.mp4', 1.6, 3.44, 3.44 / 2.28),   # 0.00  1 of these is breaking you out (glow on "out")
            clip(SRC / 'reveal.mp4', 0.3, 3.33, 3.33 / 2.22),  # 2.28  probably not the one you think
            clip(SRC / 'board.mp4', 1.0, 3.57, 3.57 / 2.1),    # 4.50  your bad days have something in common
            demo('triggers', 5.4, 2.54),                       # 6.60  Skinstel lines up every breakout…
            demo('triggers', 8.8, 1.86),                       # 9.14  …and finds the ingredient they share
            clip(SRC / 'shelf.mp4', 4.2, 0.84, 0.84 / 1.4),    # 11.00 which one is it? guess in the comments
            demo('triggers', 15.4, 3.1),                       # 12.40 end card
        ],
        caps_end=12.4, bed=('tick.mp3', -15),
        vo=[('vo.mp3', 0.00, 1.90, 0.15), ('vo.mp3', 2.38, 4.44, 2.30), ('vo.mp3', 4.96, 6.92, 4.52),
            ('vo.mp3', 7.40, 11.82, 6.50), ('vo.mp3', 12.10, 13.16, 11.02), ('vo.mp3', 13.42, 15.76, 12.42)],
        hits=[(1.70, 'bass', 1.0), (2.18, 'whoosh', 0.7), (4.42, 'boom', 0.55), (6.50, 'whoosh', 0.7),
              (9.90, 'ding', 0.6), (10.9, 'whoosh', 0.7), (12.40, 'pop', 1.2)]),
    'pov-scan': dict(
        shots=[
            clip(SRC / 'aisle.mp4', 0.2, 4.8, 4.8 / 3.75),     # 0.00  POV: you check… before you buy it
            clip(SRC / 'barcode.mp4', 2.2, 2.4, 2.4 / 1.25),   # 3.75  scan the barcode
            demo('scan', 2.6, 3.4),                            # 5.00  reads every ingredient, checks your triggers
            demo('scan', 6.6, 2.1),                            # 8.40  86. it can come home
            clip(SRC / 'aisle.mp4', 3.9, 1.1, 1.1 / 1.5),      # 10.50 what's the last thing that broke you out?
            demo('scan', 14.4, 3.1),                           # 12.00 end card
        ],
        caps_end=12.0, bed=('tick-b.mp3', -18),
        vo=[('vo-scan.mp3', 0.00, 0.76, 0.15), ('vo-scan.mp3', 1.08, 3.83, 1.05), ('vo-scan.mp3', 4.17, 5.14, 3.95),
            ('vo-scan.mp3', 5.30, 8.92, 5.05), ('vo-scan.mp3', 9.17, 11.00, 8.75), ('vo-scan.mp3', 11.23, 13.44, 12.05)],
        hits=[(3.65, 'whoosh', 0.6), (4.70, 'click', 0.9), (4.90, 'whoosh', 0.6), (8.80, 'ding', 0.6),
              (10.40, 'whoosh', 0.6), (12.00, 'pop', 1.2)]),
    'pov-conflicts': dict(
        shots=[
            still(SRC / 'serums.png', 3.85, 1.0, 1.12, (0.5, 0.56), (0.5, 0.52), 5),   # 0.00 POV: 2 of your products…
            still(SRC / 'drops.png', 2.05, 1.05, 1.28, (0.5, 0.55), shake=2),        # 3.85 every. single. night.
            demo('conflicts', 2.4, 2.6),                                             # 5.90 checks your whole routine
            demo('conflicts', 5.8, 2.3),                                             # 8.50 tells you what to change
            still(SRC / 'serums.png', 1.2, 1.5, 1.6, (0.47, 0.42), shake=4),         # 10.80 what's in your routine?
            demo('conflicts', 13.9, 3.1),                                            # 12.00 end card
        ],
        caps_end=12.0, bed=('tick.mp3', -16),
        # This take says the name as "SkinStyle", so it is spliced from the scan take (same voice): the
        # name before "checks" (cut at the stop gap before "ch", 7.00 s), and the whole comment line.
        vo=[('vo-conflicts.mp3', 0.00, 0.95, 0.15), ('vo-conflicts.mp3', 1.39, 3.96, 1.25),
            ('vo-conflicts.mp3', 4.10, 5.88, 3.90), ('vo-scan.mp3', 5.30, 5.91, 6.00),
            ('vo-conflicts.mp3', 7.00, 11.17, 6.61), ('vo-scan.mp3', 11.23, 13.44, 12.05)],
        hits=[(3.88, 'boom', 0.5), (5.80, 'whoosh', 0.6), (8.10, 'buzzer', 0.45), (10.70, 'whoosh', 0.6),
              (12.00, 'pop', 1.2)]),
    'pov-ask': dict(
        shots=[
            still(SRC / 'bed.png', 2.6, 1.0, 1.06, shake=4, flicker=True),                  # 0.00 POV: it's 1am…
            still(SRC / 'bed.png', 2.65, 1.55, 1.65, (0.56, 0.62), shake=4, flicker=True),  # 2.60 (punch in)
            demo('ask-routine', 2.5, 1.35),                                                 # 5.25 just ask Skinstel
            demo('ask-routine', 5.9, 2.02),                                                 # 6.60 builds it from what you own
            still(SRC / 'lineup.png', 1.78, 1.0, 1.08, shake=2),                            # 8.62 in the right order
            still(SRC / 'lineup.png', 1.6, 1.45, 1.52, (0.6, 0.47), shake=2),               # 10.40 what order do you do?
            demo('ask-routine', 17.4, 3.1),                                                 # 12.00 end card
        ],
        caps_end=12.0, bed=('tick-b.mp3', -17),
        vo=[('vo-ask.mp3', 0.00, 0.97, 0.15), ('vo-ask.mp3', 1.11, 5.14, 1.15), ('vo-ask.mp3', 5.47, 6.75, 5.30),
            ('vo-ask.mp3', 6.98, 10.34, 6.65), ('vo-ask.mp3', 10.59, 12.88, 12.05)],
        hits=[(2.55, 'whoosh', 0.4), (5.15, 'whoosh', 0.6), (8.62, 'sparkle', 0.8), (9.30, 'ding', 0.5),
              (12.00, 'pop', 1.2)]),
}

def render_still(dst, img, dur, z0, z1, c0, c1, shake, flicker):
    """Frames from PIL (an affine resample, sub-pixel, so slow zooms don't stair-step), piped to ffmpeg."""
    im = Image.open(img).convert('RGB')
    base_w = 1300   # downscale once so every frame resamples by a small factor
    im = im.resize((base_w, round(im.height * base_w / im.width)), Image.LANCZOS)
    W, H = im.size
    bw = min(W, H * 9 / 16)
    bh = bw * 16 / 9
    n = round(dur * 30)
    ff = subprocess.Popen(['ffmpeg', '-y', '-v', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '1080x1920',
                           '-r', '30', '-i', '-', *(['-vf', FLICKER] if flicker else []), *map(str, ENC), str(dst)],
                          stdin=subprocess.PIPE)
    for i in range(n):
        p = i / max(1, n - 1)
        e = p * p * (3 - 2 * p)
        z = z0 + (z1 - z0) * e
        w, h = bw / z, bh / z
        t = i / 30
        cx = (c0[0] + (c1[0] - c0[0]) * e) * W + shake * (w / 1080) * (math.sin(2 * math.pi * 0.7 * t) + 0.5 * math.sin(2 * math.pi * 1.9 * t + 1))
        cy = (c0[1] + (c1[1] - c0[1]) * e) * H + shake * (h / 1920) * (math.cos(2 * math.pi * 0.55 * t) + 0.5 * math.sin(2 * math.pi * 1.6 * t + 2))
        x0 = min(max(cx - w / 2, 0), W - w)
        y0 = min(max(cy - h / 2, 0), H - h)
        ff.stdin.write(im.transform((1080, 1920), Image.AFFINE, (w / 1080, 0, x0, 0, h / 1920, y0),
                                    resample=Image.BICUBIC).tobytes())
    ff.stdin.close()
    if ff.wait():
        raise SystemExit(f'ffmpeg failed on {dst}')

def loudness(path):
    out = subprocess.run(['ffmpeg', '-nostats', '-i', path, '-af', 'ebur128', '-f', 'null', '-'],
                         capture_output=True, text=True).stderr
    return float(re.findall(r'I:\s+(-?[\d.]+) LUFS', out)[-1])

def build(name):
    ad = ADS[name]
    TMP.mkdir(exist_ok=True)
    shots = []
    for k, s in enumerate(ad['shots']):
        if s[0] == 'still':
            if not s[1].exists():
                raise SystemExit(f'missing: {s[1]}')
            dst = TMP / f'{name}-{k}.mp4'
            render_still(dst, *s[1:])
            shots.append((dst, 0, s[2], 1.0, FIT))
        else:
            shots.append(s[1:])
    takes = sorted({v[0] for v in ad['vo']})
    missing = [p for p in [s[0] for s in shots] + [SRC / t for t in takes] + [SRC / ad['bed'][0]] if not p.exists()]
    if missing:
        raise SystemExit('missing: ' + ', '.join(map(str, missing)))
    run('node', VIDEO / 'render-alpha.mjs', 'roi', name)
    ins, chains = [], []
    for i, (src, ss, t, speed, vf) in enumerate(shots):
        ins += ['-ss', ss, '-t', t, '-i', src]
        chains.append(f'[{i}:v]{vf},setpts=(PTS-STARTPTS)/{speed},fps=30[v{i}]')
    n = len(shots)
    ins += ['-i', OUT / f'roi-f{name}.mov']
    fc = ';'.join(chains) + ';' + ''.join(f'[v{i}]' for i in range(n)) + f'concat=n={n}:v=1:a=0[cut];' \
         f'[{n}:v]setpts=PTS-STARTPTS[cap];[cut][cap]overlay=0:0:eof_action=pass,format=yuv420p[v]'
    silent = OUT / f'roi-{name}-silent.mp4'
    run('ffmpeg', '-y', '-v', 'error', *ins, '-filter_complex', fc, '-map', '[v]', *ENC, '-movflags', '+faststart', silent)

    # Sound cut: each voice line at its place (every take brought to the same loudness), the bed under
    # the cold open and demo, then one effect per hit.
    total = sum(s[2] / s[3] for s in shots)
    sounds = {**sfx.make(OUT / 'sfx'), **sfx.licensed(HERE / 'cache' / 'sfx')}
    srcs = [x for t in takes for x in ('-i', SRC / t)]
    gain = {t: VO_LUFS - loudness(SRC / t) for t in takes}
    mix = []
    for k, (t, a, b, at) in enumerate(ad['vo']):
        ms = int(at * 1000)
        mix.append(f'[{takes.index(t) + 1}:a]atrim={a}:{b},asetpts=PTS-STARTPTS,aresample=48000,volume={gain[t]:.1f}dB,'
                   f'afade=t=in:d=0.03,afade=t=out:st={b - a - 0.05:.2f}:d=0.05,adelay={ms}|{ms},apad[vo{k}]')
    labels = ''.join(f'[vo{k}]' for k in range(len(ad['vo'])))
    bed, bed_db = ad['bed']
    srcs += ['-i', SRC / bed]
    j = len(takes) + 1
    mix.append(f'[{j}:a]aresample=48000,volume={bed_db}dB,afade=t=out:st={ad["caps_end"] - 0.6}:d=0.8,apad[bed]')
    labels += '[bed]'
    for k, (at, snd, g) in enumerate(ad['hits']):
        srcs += ['-i', sounds[snd]]
        ms = int(at * 1000)
        mix.append(f'[{j + 1 + k}:a]aresample=48000,volume={g},adelay={ms}|{ms},apad[h{k}]')
        labels += f'[h{k}]'
    inputs = len(ad['vo']) + 1 + len(ad['hits'])
    fc = ';'.join(mix) + f';{labels}amix=inputs={inputs}:normalize=0,volume=2dB,alimiter=limit=0.85:level=false,' \
                         f'aformat=channel_layouts=stereo,atrim=0:{total:.2f}[au]'
    run('ffmpeg', '-y', '-v', 'error', '-i', silent, *srcs, '-filter_complex', fc,
        '-map', '0:v', '-map', '[au]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '160k', '-shortest',
        '-movflags', '+faststart', OUT / f'roi-{name}.mp4')
    print('→', OUT / f'roi-{name}.mp4', silent, flush=True)

if __name__ == '__main__':
    for n in [n for n in ADS if not sys.argv[1:] or n in sys.argv[1:]]:
        build(n)
