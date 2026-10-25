#!/usr/bin/env python3
"""Skit formats from the hook research, joined to the captioned app demo and its end card.

    CHROME_PATH=... python3 stock/build_skits.py                 # all
    CHROME_PATH=... python3 stock/build_skits.py text-scan glowup

    text-<story>.mp4 / -silent.mp4   text stories (textmsg.html): your skin, mom, a best friend or a
                                     class group chat texting you, then the app demo
    glowup.mp4 / -silent.mp4         high school vs college, the mascot's camera roll (glowup.html)

The sound cuts carry only sound effects (stock/sfx.py: receive tink, send whoosh, keyboard ticks,
shutter, chime, a whoosh into the demo, a pop on the end card), no music, so a trending sound can
still go on top; the silent cuts carry nothing.
"""
import json, os, subprocess, sys
import sfx
from build_stock import HERE, OUT, VIDEO, DEMO, run

ENC = ['-c:v', 'libx264', '-preset', 'slow', '-crf', 18, '-pix_fmt', 'yuv420p']
TMP = OUT / 'skits-tmp'
CTA_TAIL = 3.1   # the f-*.mp4 end card, from 0.4 s after its cross-fade

# name: (page, query, demo, start and end of the captioned demo in f-<demo>.mp4)
SKITS = {
    'text-conflicts': ('textmsg', 's=conflicts', 'conflicts', 1.6, 11.0),
    'text-scan': ('textmsg', 's=scan', 'scan', 0.4, 11.6),
    'text-triggers': ('textmsg', 's=triggers', 'triggers', 0.8, 13.4),
    'text-mom': ('textmsg', 's=mom', 'conflicts', 1.6, 11.0),
    'text-bestie': ('textmsg', 's=bestie', 'scan', 0.4, 11.6),
    'text-class': ('textmsg', 's=class', 'triggers', 0.8, 13.4),
    'glowup': ('glowup', '', 'triggers', 0.8, 13.4),
}
SOUNDS = {**sfx.make(OUT / 'sfx'), **sfx.licensed(HERE / 'cache' / 'sfx')}
# The glow-up's cues predate the sound set's names.
ALIAS = {'them': 'recv', 'me': 'send'}

def page(name, pg, query):
    suffix = '-' + name
    run('node', VIDEO / 'render.mjs', pg, 30, 1, suffix, env={**os.environ, 'QUERY': query, 'FMT': 'jpeg'})
    mp4 = OUT / f'skintel-{pg}{suffix}.mp4'
    cues = json.loads((OUT / f'skintel-{pg}{suffix}.cues.json').read_text())
    return mp4, cues

def demo(name, d, s, e):
    """The captioned app video from s to e, then its end card."""
    dst = TMP / f'{name}-demo.mp4'
    cta = DEMO[d][1] + 0.4
    full = OUT / f'skintel-f-{d}.mp4'
    run('ffmpeg', '-y', '-v', 'error', '-ss', s, '-t', e - s, '-i', full, '-ss', cta, '-t', CTA_TAIL, '-i', full,
        '-filter_complex', '[0:v]fps=30,setsar=1[a];[1:v]fps=30,setsar=1[b];[a][b]concat=n=2:v=1:a=0[v]',
        '-map', '[v]', *ENC, dst)
    return dst

def build(name):
    TMP.mkdir(exist_ok=True)
    pg, query, d, s, e = SKITS[name]
    skit, cues = page(name, pg, query)
    body = demo(name, d, s, e)
    silent = OUT / f'{name}-silent.mp4'
    run('ffmpeg', '-y', '-v', 'error', '-i', skit, '-i', body,
        '-filter_complex', '[0:v]fps=30,setsar=1[a];[1:v]fps=30,setsar=1[b];[a][b]concat=n=2:v=1:a=0[v]',
        '-map', '[v]', *ENC, '-movflags', '+faststart', silent)
    # Sound cut: one effect per cue, plus a whoosh into the demo and a pop as the end card lands.
    skit_len = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', skit],
                                    capture_output=True, text=True).stdout)
    cues = [[t, ALIAS.get(k, k)] for t, k in cues] + [[skit_len - 0.25, 'whoosh'], [skit_len + (e - s) + 0.05, 'pop']]
    srcs, mix = [], []
    for i, (t, kind) in enumerate(cues):
        srcs += ['-i', SOUNDS[kind]]
        ms = int(round(max(0, t) * 1000))
        mix.append(f'[{i + 1}:a]aresample=48000,adelay={ms}|{ms},apad[s{i}]')
    labels = ''.join(f'[s{i}]' for i in range(len(cues)))
    fc = ';'.join(mix) + f';{labels}amix=inputs={len(cues)}:normalize=0,volume=-4dB,alimiter=limit=0.7:level=false,aformat=channel_layouts=stereo[au]'
    run('ffmpeg', '-y', '-v', 'error', '-i', silent, *srcs, '-filter_complex', fc,
        '-map', '0:v', '-map', '[au]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '160k', '-shortest', '-movflags', '+faststart',
        OUT / f'{name}.mp4')
    print('→', OUT / f'{name}.mp4', silent, flush=True)

if __name__ == '__main__':
    for n in [n for n in SKITS if not sys.argv[1:] or n in sys.argv[1:]]:
        build(n)
