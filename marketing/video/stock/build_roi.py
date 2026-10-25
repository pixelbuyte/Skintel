#!/usr/bin/env python3
"""The "1 of these is breaking you out" ad: cinematic AI B-roll → the triggers demo → Comment SKINSTEL.

    CHROME_PATH=... python3 stock/build_roi.py

Writes out/roi-1ofthese.mp4 (voiceover + sound effects) and out/roi-1ofthese-silent.mp4 (captions
only, for a trending sound). The beats: a crowded shelf where one bottle lights up red ("1 of these
is breaking you out"), a hand pulling one bottle from a lineup ("probably not the one you think"),
a pinboard with red string from circled days to one bottle ("your bad days have something in
common"), the app lining breakouts up and naming the ingredient, back to the red bottle with a
comment prompt (guesses are comments), then the end card.

Footage in stock/cache/roi/ (gitignored), made in the ElevenLabs flow "Skinstel ROI ad" (Seedance 2.5,
720p 9:16, no people's faces, unbranded bottles): shelf.mp4, reveal.mp4, board.mp4; the voiceover
vo.mp3 (Roxie, eleven_v4); the tension bed tick.mp3 (ElevenLabs sound effects: ticking clock and
sub drone, no music). Captions come from roi.html (render-alpha.mjs roi 1); keep its CAPS on SHOTS.
"""
import subprocess
import sfx
from build_stock import HERE, OUT, VIDEO, run

SRC = HERE / 'cache' / 'roi'
F = OUT / 'skintel-f-triggers.mp4'
ENC = ['-c:v', 'libx264', '-preset', 'slow', '-crf', 18, '-pix_fmt', 'yuv420p']
AI = 'scale=1080:1920:flags=lanczos,unsharp=5:5:0.6,setsar=1'
FIT = 'scale=1080:1920,setsar=1'

# (source, start, source length, speed, filter). Speeds are chosen so each shot fills its beat: the
# shelf's red glow (4.2 s in the clip) lands at 1.72 s, on "out".
SHOTS = [
    (SRC / 'shelf.mp4', 1.6, 3.44, 3.44 / 2.28, AI),      # 0.00  1 of these is breaking you out
    (SRC / 'reveal.mp4', 0.3, 3.33, 3.33 / 2.22, AI),     # 2.28  probably not the one you think
    (SRC / 'board.mp4', 1.0, 3.57, 3.57 / 2.1, AI),      # 4.50  your bad days have something in common
    (F, 5.4, 2.54, 1.0, FIT),                             # 6.60  Skinstel lines up every breakout…
    (F, 8.8, 1.86, 1.0, FIT),                             # 9.14  …and finds the ingredient they share
    (SRC / 'shelf.mp4', 4.2, 0.84, 0.84 / 1.4, AI),       # 11.00 which one is it? guess in the comments
    (F, 15.4, 3.1, 1.0, FIT),                             # 12.40 Comment SKINSTEL end card
]
CAPS_END = 12.4
# Voiceover take: [start, end] of each spoken line in vo.mp3 (faster-whisper word times, padded),
# and where it plays in the cut. Gaps are tightened to ~0.2 s so the read never stalls.
VO = [((0.00, 1.90), 0.15), ((2.38, 4.44), 2.30), ((4.96, 6.92), 4.52),
      ((7.40, 11.82), 6.50), ((12.10, 13.16), 11.02), ((13.42, 15.76), 12.42)]
# (time, sound, gain): bass on the red glow, whooshes on the cuts, a boom as the board lands, a ding
# as the ingredient is named, a pop on the end card.
HITS = [(1.70, 'bass', 1.0), (2.18, 'whoosh', 0.7), (4.42, 'boom', 0.55), (6.50, 'whoosh', 0.7),
        (9.90, 'ding', 0.6), (10.9, 'whoosh', 0.7), (12.40, 'pop', 1.2)]

def main():
    missing = [p for p in [s[0] for s in SHOTS] + [SRC / 'vo.mp3', SRC / 'tick.mp3', F] if not p.exists()]
    if missing:
        raise SystemExit('missing: ' + ', '.join(map(str, missing)))
    run('node', VIDEO / 'render-alpha.mjs', 'roi', 1)
    ins, chains = [], []
    for i, (src, ss, t, speed, vf) in enumerate(SHOTS):
        ins += ['-ss', ss, '-t', t, '-i', src]
        chains.append(f'[{i}:v]{vf},setpts=(PTS-STARTPTS)/{speed},fps=30[v{i}]')
    n = len(SHOTS)
    ins += ['-i', OUT / 'roi-f1.mov']
    fc = ';'.join(chains) + ';' + ''.join(f'[v{i}]' for i in range(n)) + f'concat=n={n}:v=1:a=0[cut];' \
         f'[{n}:v]setpts=PTS-STARTPTS[cap];[cut][cap]overlay=0:0:eof_action=pass,format=yuv420p[v]'
    silent = OUT / 'roi-1ofthese-silent.mp4'
    run('ffmpeg', '-y', '-v', 'error', *ins, '-filter_complex', fc, '-map', '[v]', *ENC, '-movflags', '+faststart', silent)

    total = sum(s[2] / s[3] for s in SHOTS)
    sounds = {**sfx.make(OUT / 'sfx'), **sfx.licensed(HERE / 'cache' / 'sfx')}
    srcs, mix = ['-i', SRC / 'vo.mp3', '-i', SRC / 'tick.mp3'], []
    for k, ((a, b), at) in enumerate(VO):
        ms = int(at * 1000)
        mix.append(f'[1:a]atrim={a}:{b},asetpts=PTS-STARTPTS,aresample=48000,afade=t=in:d=0.03,'
                   f'afade=t=out:st={b - a - 0.05}:d=0.05,adelay={ms}|{ms},apad[vo{k}]')
    mix.append(''.join(f'[vo{k}]' for k in range(len(VO))) + f'amix=inputs={len(VO)}:normalize=0,volume=12dB[vo]')
    # The tension bed sits under the voice through the cold open and demo, then fades for the end card.
    mix.append(f'[2:a]aresample=48000,volume=-15dB,afade=t=out:st={CAPS_END - 0.6}:d=0.8,apad[bed]')
    labels = '[vo][bed]'
    for k, (at, name, gain) in enumerate(HITS):
        srcs += ['-i', sounds[name]]
        ms = int(at * 1000)
        mix.append(f'[{k + 3}:a]aresample=48000,volume={gain},adelay={ms}|{ms},apad[h{k}]')
        labels += f'[h{k}]'
    fc = ';'.join(mix) + f';{labels}amix=inputs={len(HITS) + 2}:normalize=0,volume=2dB,alimiter=limit=0.85:level=false,' \
                         f'aformat=channel_layouts=stereo,atrim=0:{total:.2f}[au]'
    run('ffmpeg', '-y', '-v', 'error', '-i', silent, *srcs, '-filter_complex', fc,
        '-map', '0:v', '-map', '[au]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '160k', '-shortest',
        '-movflags', '+faststart', OUT / 'roi-1ofthese.mp4')
    print('→', OUT / 'roi-1ofthese.mp4', silent)

if __name__ == '__main__':
    main()
