#!/usr/bin/env python3
"""Native-looking formats: "name of this app is…" screen-recording reveals and a photo carousel.

    CHROME_PATH=... python3 stock/build_reveal.py

    out/reveal-<name>.mp4   the raw iPhone screen recording of the app (our f-*-screen renders), sped
                            up, on black, with TikTok-style text (reveal.html). Silent on purpose: the
                            format runs on a trending sound added in the app (BloomSkin's 4.8M used
                            MONTAGEM GREEN RENITCH).
      out/carousel/slide-N.png  "skincare things nobody tells you", Skinstel on slides 5–6 (carousel.html).

Why: in the scrapes (HOOKS.md) the app videos that travel are short, raw and native, from tiny
accounts, not polished ads.
"""
from build_stock import OUT, VIDEO, run

ENC = ['-c:v', 'libx264', '-preset', 'slow', '-crf', 18, '-pix_fmt', 'yuv420p']
# name: (screen render, start, source length, speed). Output length = source length / speed; keep
# reveal.html's durations equal to it.
REVEALS = {
    'triggers': ('triggers', 0.3, 12.76, 1.45),   # 8.8 s: one-tap log → Triggers
    'scan': ('scan', 0.2, 10.8, 1.35),            # 8.0 s: barcode → 86 verdict
    'conflicts': ('conflicts', 0.3, 9.75, 1.3),   # 7.5 s: routine → 2 conflicts and the fix
}
# Frames of the screen renders used as app screenshots in the carousel: (render, time, file).
SHOTS = [('triggers', 9.0, 'shot-triggers.png'), ('scan', 12.0, 'shot-scan.png')]

def reveal(name):
    screen, ss, t, speed = REVEALS[name]
    run('node', VIDEO / 'render-alpha.mjs', 'reveal', name)
    dst = OUT / f'reveal-{name}.mp4'
    fc = (f'[0:v]setpts=(PTS-STARTPTS)/{speed},fps=30,scale=-2:1920:flags=lanczos,setsar=1,'
          f'pad=1080:1920:(ow-iw)/2:0:black[s];[1:v]setpts=PTS-STARTPTS[c];'
          f'[s][c]overlay=0:0:eof_action=pass,format=yuv420p[v]')
    run('ffmpeg', '-y', '-v', 'error', '-ss', ss, '-t', t, '-i', OUT / f'skintel-f-{screen}-screen.mp4',
        '-i', OUT / f'reveal-f{name}.mov', '-filter_complex', fc, '-map', '[v]', '-t', round(t / speed, 2),
        *ENC, '-movflags', '+faststart', dst)
    print('→', dst, flush=True)

def carousel():
    d = OUT / 'carousel'
    d.mkdir(exist_ok=True)
    for screen, at, fname in SHOTS:
        run('ffmpeg', '-y', '-v', 'error', '-ss', at, '-i', OUT / f'skintel-f-{screen}-screen.mp4',
            '-frames:v', 1, d / fname)
    run('node', VIDEO / 'shoot-carousel.mjs')
    print('→', d, flush=True)

if __name__ == '__main__':
    for n in REVEALS:
        reveal(n)
    carousel()
