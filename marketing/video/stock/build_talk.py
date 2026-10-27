#!/usr/bin/env python3
"""Talking-skin hook videos ("POV: your skin can finally talk"): the Skintel mascot, animated with
Kling 3.0 on Higgsfield from the brand art, says one line with its own voice → the live Skintel demo
on a real hand-held phone (the stock-* bodies from build_stock.py) → the Comment SKINSTEL card.

    CHROME_PATH=... python3 stock/build_talk.py              # all
    CHROME_PATH=... python3 stock/build_talk.py scan         # one

The format is the "talking pore/skin creature" skit from the hook research (HOOKS.md): a cartoon
brand character, never an AI person posing as a customer. Run build_stock.py first so the demo
bodies exist. Text comes from talk.html (render-alpha.mjs); keep hook/body in sync with TALKS there.
"""
import sys
from build_stock import OUT, VIDEO, DEMO, clip, run

# name: (mascot clip, trim start, hook length, x of the 1080-wide window in the clip scaled to
# 1260, centring the mascot's measured extent, demo body from build_stock.py, body length). Bodies end once the result has been on
# screen long enough to read; the hold after that is cut, not sped up.
TALKS = {
    'conflicts': ('talk-conflicts', 0.0, 4.95, 120, 'stock-02-conflicts', 8.0),
    'scan': ('talk-scan', 1.0, 3.95, 84, 'stock-06-scan', 9.4),
    'triggers': ('talk-triggers', 1.3, 3.7, 88, 'stock-01-triggers', 8.5),
}
CTA_LEN = 2.6

def overlay(name):
    run('node', VIDEO / 'render-alpha.mjs', 'talk', name)
    return OUT / f'talk-f{name}.mov'

def build(name):
    src, ss, hook, x, body, blen = TALKS[name]
    demo = body.split('-', 2)[2]
    cta = DEMO[demo][1]
    ov = overlay(name)
    total = hook + blen + CTA_LEN
    # The Kling clip is square: a 1080×1260 window of it scaled to 1260 (the whole mascot fits), over
    # a blurred, darker copy filling the bands above and below. Its voice plays under the hook; the rest is silent for a trending sound.
    fc = (f"[0:v]split[a][b];"
          f"[a]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,gblur=sigma=70,eq=brightness=-0.22[bg];"
          f"[b]scale=1260:1260:flags=lanczos,crop=1080:1260:{x}:0,unsharp=5:5:0.5[fg];"
          f"[bg][fg]overlay=0:340,fps=30,setsar=1[h];"
          f"[1:v]fps=30,setsar=1[bd];[3:v]fps=30,setsar=1[c];"
          f"[h][bd]concat=n=2:v=1:a=0[m];[m][2:v]overlay=0:0:eof_action=pass[mo];"
          f"[mo][c]concat=n=2:v=1:a=0,format=yuv420p[v];"
          f"[0:a]aresample=48000,afade=t=out:st={hook - 0.15}:d=0.15,apad=whole_dur={total}[au]")
    final = OUT / f'talk-{name}.mp4'
    run('ffmpeg', '-y', '-v', 'error',
        '-ss', ss, '-t', hook, '-i', clip(src),
        '-t', blen, '-i', OUT / 'stock-tmp' / f'{body}-body.mp4',
        '-i', ov,
        '-ss', cta + 0.4, '-t', CTA_LEN, '-i', OUT / f'skintel-f-{demo}.mp4',
        '-filter_complex', fc, '-map', '[v]', '-map', '[au]', '-t', total,
        '-c:v', 'libx264', '-preset', 'slow', '-crf', 18, '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', final)
    print('→', final, flush=True)

if __name__ == '__main__':
    picks = [n for n in TALKS if not sys.argv[1:] or n in sys.argv[1:]]
    for n in picks:
        build(n)
