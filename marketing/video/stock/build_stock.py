#!/usr/bin/env python3
"""Real-footage hook videos: hook line over faceless stock B-roll (2.2 s) → the live Skintel demo
mapped onto a real hand-held phone → the Comment SKINSTEL card.

    CHROME_PATH=... python3 stock/build_stock.py              # all
    CHROME_PATH=... python3 stock/build_stock.py stock-02     # one

Stock clips come from clips.json (Pexels / Mixkit, faceless, labels blurred) and are cached in
stock/cache/. Hook text PNGs come from build-hooks.mjs (out/hook-kit/text-NN.png); the demo screen
from f-*.html?mode=screen; the end card from the full f-*.mp4.
"""
import json, os, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
VIDEO = HERE.parent
OUT = VIDEO / 'out'
CACHE = HERE / 'cache'
CLIPS = json.loads((HERE / 'clips.json').read_text())['clips']

# Demo timings (seconds in the f-*.html timeline): where the demo starts after the cut, and where
# its end card begins.
DEMO = {
    'conflicts': (1.6, 13.5), 'scan': (0.4, 14.0), 'triggers': (0.8, 15.0),
    'ask-when': (0.8, 13.0), 'ask-tag': (0.7, 15.0), 'ask-routine': (0.8, 17.0),
}
# name: (hook number, B-roll clip, B-roll start, phone clip, zoom, demo)
VIDEOS = {
    'stock-02-conflicts': (2, 'serum-drip', 5.0, 'hands-white', 1.4, 'conflicts'),
    'stock-06-scan': (6, 'shop-shelves', 2.0, 'hand-laptop-white', 1.3, 'scan'),
    'stock-01-triggers': (1, 'cream-jar', 1.5, 'hand-green-outdoor', 1.25, 'triggers'),
    'stock-07-ask-when': (7, 'water-drop', 2.0, 'hands-white', 1.4, 'ask-when'),
    'stock-10-ask-tag': (10, 'hand-cream', 6.0, 'hand-laptop-white', 1.3, 'ask-tag'),
    'stock-11-conflicts': (11, 'shop-shelves', 5.5, 'hand-green-outdoor', 1.25, 'conflicts'),
}

def run(*cmd, **kw):
    subprocess.run([str(c) for c in cmd], check=True, **kw)

def clip(name):
    """Download a stock clip once."""
    CACHE.mkdir(exist_ok=True)
    path = CACHE / f'{name}.mp4'
    if not path.exists():
        run('curl', '-sSL', '-A', 'Mozilla/5.0', '--max-time', '300', '-o', path, CLIPS[name]['url'])
    return path

def screen(demo):
    path = OUT / f'skintel-f-{demo}-screen.mp4'
    if not path.exists():
        run('node', VIDEO / 'render.mjs', f'f-{demo}', '30', '1', '-screen',
            env={**os.environ, 'QUERY': 'mode=screen', 'VW': '886', 'VH': '1918', 'FMT': 'jpeg'})
    return path

def hook_clip(h, broll, ss, dst):
    """B-roll → 1080×1920 (centre-cropped if landscape, blurred if its labels are readable), slow
    push-in, the hook line in TikTok Sans on top."""
    c = CLIPS[broll]
    blur = f",gblur=sigma={c['blur']}" if c.get('blur') else ''
    vf = (f"[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920{blur},"
          f"scale=w='1080*(1+0.05*t/2.2)':h=-2:eval=frame,crop=1080:1920,fps=30,setsar=1[bg];"
          f"[bg][1:v]overlay=0:0[v]")
    run('ffmpeg', '-y', '-v', 'error', '-ss', ss, '-t', 2.2, '-i', clip(broll), '-i', OUT / 'hook-kit' / f'text-{h:02d}.png',
        '-filter_complex', vf, '-map', '[v]', '-an', '-c:v', 'libx264', '-preset', 'slow', '-crf', 18, '-pix_fmt', 'yuv420p', dst)

def build(name):
    h, broll, ss, phone, zoom, demo = VIDEOS[name]
    start, cta = DEMO[demo]
    tmp = OUT / 'stock-tmp'; tmp.mkdir(exist_ok=True)
    hook = tmp / f'{name}-hook.mp4'; body = tmp / f'{name}-body.mp4'
    hook_clip(h, broll, ss, hook)
    green = ['--green'] if CLIPS[phone].get('screen') == 'green' else []
    run(sys.executable, HERE / 'composite.py', clip(phone), screen(demo), body, '--start', start, '--end', cta, '--zoom', zoom, *green)
    full = OUT / f'skintel-f-{demo}.mp4'   # its end card, from 0.4 s in (past the cross-fade)
    final = OUT / f'{name}.mp4'
    run('ffmpeg', '-y', '-v', 'error', '-i', hook, '-i', body, '-ss', cta + 0.4, '-i', full,
        '-filter_complex', '[0:v][1:v][2:v]concat=n=3:v=1:a=0,format=yuv420p[v]', '-map', '[v]',
        '-c:v', 'libx264', '-preset', 'slow', '-crf', 18, '-movflags', '+faststart', final)
    print('→', final, flush=True)

if __name__ == '__main__':
    picks = [n for n in VIDEOS if not sys.argv[1:] or any(n.startswith(a) for a in sys.argv[1:])]
    for n in picks:
        build(n)
