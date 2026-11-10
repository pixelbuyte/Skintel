#!/usr/bin/env python3
"""The Fastlane / Cal AI reaction ad with a real face: yours, or a real user's who agreed.

    python3 stock/build_selfie.py MY_REACTION.mov --hook 1 --demo triggers
    python3 stock/build_selfie.py MY_REACTION.mov --hook 6 --demo scan --start 0.4 --keep-audio

Film 2–3 seconds of yourself reacting (hand over mouth, wide eyes, looking from the phone to the
camera), vertical, at arm's length, window light. This crops it to 9:16, puts hook line N from
hook.html on it (out/hook-kit/text-NN.png, made by build-hooks.mjs), then cuts to the app on a real
hand-held phone (build_stock.py's bodies) and the Comment SKINSTEL end card.

First-person lines ("I", "my") only for someone they're true for. No stand-ins, no AI faces: a
reaction from someone who didn't have the experience is a fake testimonial.
"""
import argparse, subprocess
from build_stock import OUT, DEMO, VIDEOS, run

# The real-hands body for each demo (the first stock-* video that uses it).
BODY = {}
for name, (*_, demo) in VIDEOS.items():
    BODY.setdefault(demo, name)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('clip')
    ap.add_argument('--hook', type=int, required=True, help='hook number from hook.html (text-NN.png)')
    ap.add_argument('--demo', required=True, choices=sorted(BODY))
    ap.add_argument('--start', type=float, default=0.0, help='where the reaction starts in your clip')
    ap.add_argument('--len', type=float, default=2.2, help='reaction length; 1.5–2.5 s holds best')
    ap.add_argument('--keep-audio', action='store_true', help='keep your clip\'s sound under the reaction')
    a = ap.parse_args()

    text = OUT / 'hook-kit' / f'text-{a.hook:02d}.png'
    body = OUT / 'stock-tmp' / f'{BODY[a.demo]}-body.mp4'
    full = OUT / f'skintel-f-{a.demo}.mp4'
    for p in (text, body, full):
        if not p.exists():
            raise SystemExit(f'missing {p}: run build-hooks.mjs and build_stock.py first')
    start, cta = DEMO[a.demo]
    dst = OUT / f'selfie-{a.hook:02d}-{a.demo}.mp4'
    fc = (f"[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,fps=30,setsar=1[r];"
          f"[r][1:v]overlay=0:0[h];[2:v]fps=30,setsar=1[b];[3:v]fps=30,setsar=1[c];"
          f"[h][b][c]concat=n=3:v=1:a=0,format=yuv420p[v]")
    audio = []
    has_audio = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'a', '-show_entries', 'stream=index',
                                '-of', 'csv=p=0', a.clip], capture_output=True, text=True).stdout.strip()
    if a.keep_audio and not has_audio:
        print('note: the clip has no sound; making a silent video')
    if a.keep_audio and has_audio:
        total = a.len + (cta - start) + 3.1
        fc += f";[0:a]aresample=48000,afade=t=out:st={a.len - 0.15}:d=0.15,apad=whole_dur={total}[au]"
        audio = ['-map', '[au]', '-c:a', 'aac', '-b:a', '160k', '-t', total]
    run('ffmpeg', '-y', '-v', 'error', '-ss', a.start, '-t', a.len, '-i', a.clip, '-i', text,
        '-i', body, '-ss', cta + 0.4, '-t', 3.1, '-i', full,
        '-filter_complex', fc, '-map', '[v]', *audio,
        '-c:v', 'libx264', '-preset', 'slow', '-crf', 18, '-movflags', '+faststart', dst)
    print('→', dst)

if __name__ == '__main__':
    main()
