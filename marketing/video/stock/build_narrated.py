#!/usr/bin/env python3
"""Videos where the Skintel mascot talks the whole way through, plus POV reaction versions.

    CHROME_PATH=... python3 stock/build_narrated.py              # all
    CHROME_PATH=... python3 stock/build_narrated.py scan         # one demo

For each demo (conflicts, scan, triggers) it writes four videos to out/:
    mascot-<demo>.mp4         talking-skin hook → the mascot narrates our own app video → the mascot
                              says "Comment Skinstel" on the end card (voice all the way)
    mascot-<demo>-silent.mp4  the same with no sound, captions only, for a trending sound
    pov-<demo>.mp4            POV line over a reaction shot → the narrated app video (voice)
    pov-<demo>-silent.mp4     POV reaction → the full captioned app video f-<demo>.mp4, no sound

The narrator clips are Kling 3.0 clips of the mascot on a flat blue screen (stock/clips.json), keyed
out here and laid over the app video. Run build_talk.py first (it renders the talk-f*.mov overlays
the hooks reuse). Text comes from narr.html; keep NARR in sync with it.
"""
import sys
import numpy as np
from PIL import Image
from build_stock import OUT, VIDEO, DEMO, clip, run
from build_talk import TALKS

KEY = 'chromakey=color=0x0548B9:similarity=0.14:blend=0.06,despill=type=blue'
# The f-*-body renders' background: a soft four-corner gradient (sampled RGB), so the shrunken
# app video and the end card sit on the same paper.
CORNERS = [(227, 205, 187), (209, 210, 200), (206, 197, 179), (205, 187, 166)]
DEMO_W, DEMO_H, DEMO_X, DEMO_Y = 778, 1383, 151, 250
NARR_LEN = 7.0
AUDIO = 'aresample=48000,aformat=channel_layouts=stereo'
ENC = ['-c:v', 'libx264', '-preset', 'slow', '-crf', 18, '-pix_fmt', 'yuv420p']
TMP = OUT / 'narr-tmp'

# demo: (narrator clip, where the app video starts in the f-<demo> timeline so its result lands on
# the mascot's words, where the demo cuts to the end card in the narrator clip, POV reaction shot:
# a stretch of the talking-skin clip with its sound off).
NARR = {
    'conflicts': ('narr-conflicts', 3.8, 4.8, 1.0, 2.4),
    'scan': ('narr-scan', 4.0, 4.8, 1.0, 2.2),
    'triggers': ('narr-triggers', 3.6, 5.0, 1.3, 2.3),
}

def plates():
    """The background gradient and a feathered mask for the app video's edges."""
    bg, mask = TMP / 'bg.png', TMP / 'mask.png'
    if not bg.exists():
        y, x = np.mgrid[0:1920, 0:1080]; u, v = (x / 1079)[..., None], (y / 1919)[..., None]
        tl, tr, bl, br = (np.array(c, float) for c in CORNERS)
        img = (1 - v) * ((1 - u) * tl + u * tr) + v * ((1 - u) * bl + u * br)
        Image.fromarray(img.astype(np.uint8)).save(bg)
        yy, xx = np.mgrid[0:DEMO_H, 0:DEMO_W]
        d = np.minimum.reduce([xx, yy, DEMO_W - 1 - xx, DEMO_H - 1 - yy]).astype(float)
        Image.fromarray((np.clip(d / 70, 0, 1) * 255).astype(np.uint8)).save(mask)
    return bg, mask

def alpha(page, f):
    run('node', VIDEO / 'render-alpha.mjs', page, f)
    return OUT / f'{page}-f{f}.mov'

def vertical(x):
    """The square Kling clip as 9:16: a 1080×1260 window scaled to 1260 over a blurred fill
    (same treatment as build_talk.py)."""
    return (f"split[a][b];[a]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,"
            f"gblur=sigma=70,eq=brightness=-0.22[bg];[b]scale=1260:1260:flags=lanczos,crop=1080:1260:{x}:0,"
            f"unsharp=5:5:0.5[fg];[bg][fg]overlay=0:340,fps=30,setsar=1")

def hook(demo, pov):
    """The talking-skin hook with its voice, or a muted reaction stretch of it with the POV line."""
    src, ss, length, x = TALKS[demo][:4]
    if pov:
        ss, length = NARR[demo][3:5]
        ov = alpha('narr', f'pov-{demo}')
    else:
        ov = OUT / f'talk-f{demo}.mov'
    dst = TMP / f'hook-{"pov" if pov else "talk"}-{demo}.mp4'
    audio = (f"anullsrc=r=48000:cl=stereo,atrim=0:{length}[au]" if pov
             else f"[0:a]{AUDIO},afade=t=out:st={length - 0.15}:d=0.15[au]")
    run('ffmpeg', '-y', '-v', 'error', '-ss', ss, '-t', length, '-i', clip(src), '-i', ov,
        '-filter_complex', f"[0:v]{vertical(x)}[h];[h][1:v]overlay=0:0:eof_action=pass[v];{audio}",
        '-map', '[v]', '-map', '[au]', '-t', length, *ENC, '-c:a', 'aac', '-b:a', '160k', dst)
    return dst

def narrated(demo):
    """Our own app video (the f-<demo> body render, phone in hand) with the keyed mascot talking
    in the corner, then the end card with the mascot big over it."""
    src, start, cut = NARR[demo][:3]
    ov = alpha('narr', demo)
    bg, mask = plates()
    dst = TMP / f'narr-{demo}.mp4'
    fc = (f"[3:v]fps=30,setsar=1,format=rgb24[paper];[4:v]format=gray[mk];"
          f"[0:v]scale={DEMO_W}:{DEMO_H},fps=30,setsar=1,format=rgba[d0];[d0][mk]alphamerge[dm];"
          f"[paper][dm]overlay={DEMO_X}:{DEMO_Y}:eof_action=pass[base];"
          f"[1:v]{KEY},fps=30,split[ka][kb];[ka]scale=700:700[ks];[kb]scale=1000:1000[kl];"
          f"[base][ks]overlay=-90:1250:enable='lt(t,{cut})'[b1];[b1][kl]overlay=40:150:enable='gte(t,{cut})'[b2];"
          f"[b2][2:v]overlay=0:0,format=yuv420p[v];[1:a]{AUDIO}[au]")
    run('ffmpeg', '-y', '-v', 'error', '-ss', start, '-t', cut, '-i', OUT / f'skintel-f-{demo}-body.mp4',
        '-i', clip(src), '-i', ov, '-loop', 1, '-t', NARR_LEN, '-i', bg, '-loop', 1, '-t', cut, '-i', mask, '-filter_complex', fc, '-map', '[v]', '-map', '[au]', '-t', NARR_LEN,
        *ENC, '-c:a', 'aac', '-b:a', '160k', dst)
    return dst

def full_demo(demo):
    """The finished captioned app video from where its demo starts, end card included, silent."""
    dst = TMP / f'full-{demo}.mp4'
    run('ffmpeg', '-y', '-v', 'error', '-ss', DEMO[demo][0], '-i', OUT / f'skintel-f-{demo}.mp4',
        '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo', '-map', '0:v', '-map', '1:a', '-shortest',
        '-vf', 'fps=30,setsar=1', *ENC, '-c:a', 'aac', dst)
    return dst

def join(parts, dst, sound):
    ins = [a for p in parts for a in ('-i', p)]
    a = 1 if sound else 0
    fc = ''.join(f'[{i}:v]' + (f'[{i}:a]' if sound else '') for i in range(len(parts))) + \
        f'concat=n={len(parts)}:v=1:a={a}[v]' + ('[a]' if sound else '')
    maps = ['-map', '[v]'] + (['-map', '[a]', '-c:a', 'aac', '-b:a', '160k'] if sound else ['-an'])
    run('ffmpeg', '-y', '-v', 'error', *ins, '-filter_complex', fc, *maps, *ENC, '-movflags', '+faststart', dst)
    print('→', dst, flush=True)

def build(demo):
    TMP.mkdir(exist_ok=True)
    talk, pov, body = hook(demo, False), hook(demo, True), narrated(demo)
    join([talk, body], OUT / f'mascot-{demo}.mp4', True)
    join([talk, body], OUT / f'mascot-{demo}-silent.mp4', False)
    join([pov, body], OUT / f'pov-{demo}.mp4', True)
    join([pov, full_demo(demo)], OUT / f'pov-{demo}-silent.mp4', False)

if __name__ == '__main__':
    for d in [d for d in NARR if not sys.argv[1:] or d in sys.argv[1:]]:
        build(d)
