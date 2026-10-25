#!/usr/bin/env python3
"""Skit formats from the hook research, joined to the captioned app demo and its end card.

    CHROME_PATH=... python3 stock/build_skits.py                 # all
    CHROME_PATH=... python3 stock/build_skits.py text-scan glowup

    text-<story>.mp4 / -silent.mp4   text stories (textmsg.html): your skin, dad, a best friend or a
                                     class group chat texting you, then the app demo
    glowup.mp4 / -silent.mp4         high school vs college, the mascot's camera roll (glowup.html)

The sound cuts carry only sound effects synthesized here (message pops, a shutter click, a chime),
so a trending sound can still go on top; the silent cuts carry nothing.
"""
import json, os, sys
from build_stock import OUT, VIDEO, DEMO, run

ENC = ['-c:v', 'libx264', '-preset', 'slow', '-crf', 18, '-pix_fmt', 'yuv420p']
TMP = OUT / 'skits-tmp'
CTA_TAIL = 3.1   # the f-*.mp4 end card, from 0.4 s after its cross-fade

# name: (page, query, demo, start and end of the captioned demo in f-<demo>.mp4)
SKITS = {
    'text-conflicts': ('textmsg', 's=conflicts', 'conflicts', 1.6, 11.0),
    'text-scan': ('textmsg', 's=scan', 'scan', 0.4, 11.6),
    'text-triggers': ('textmsg', 's=triggers', 'triggers', 0.8, 13.4),
    'text-dad': ('textmsg', 's=dad', 'conflicts', 1.6, 11.0),
    'text-bestie': ('textmsg', 's=bestie', 'scan', 0.4, 11.6),
    'text-class': ('textmsg', 's=class', 'triggers', 0.8, 13.4),
    'glowup': ('glowup', '', 'triggers', 0.8, 13.4),
}
# Sound effects, synthesized (no samples, nothing to license).
SFX = {
    'them': "0.5*sin(2*PI*t*(520+380*exp(-35*t)))*exp(-22*t)",
    'me': "0.45*sin(2*PI*t*(900+500*exp(-30*t)))*exp(-26*t)",
    'click': "(random(0)*2-1)*0.7*(exp(-70*t)+0.6*exp(-70*abs(t-0.07))*gte(t,0.07))",
    'sparkle': "0.25*(sin(2*PI*1568*t)+sin(2*PI*2093*t)+0.6*sin(2*PI*3136*t))*exp(-9*t)",
}

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
    # Sound cut: one effect per cue, mixed onto silence the length of the video.
    srcs, mix = [], []
    for i, (t, kind) in enumerate(cues):
        srcs += ['-f', 'lavfi', '-i', f"aevalsrc='{SFX[kind]}':s=48000:d=0.25"]
        ms = int(round(t * 1000))
        mix.append(f'[{i + 1}:a]adelay={ms}|{ms},apad[s{i}]')
    labels = ''.join(f'[s{i}]' for i in range(len(cues)))
    fc = ';'.join(mix) + f';{labels}amix=inputs={len(cues)}:normalize=0,aformat=channel_layouts=stereo[au]'
    run('ffmpeg', '-y', '-v', 'error', '-i', silent, *srcs, '-filter_complex', fc,
        '-map', '0:v', '-map', '[au]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '160k', '-shortest', '-movflags', '+faststart',
        OUT / f'{name}.mp4')
    print('→', OUT / f'{name}.mp4', silent, flush=True)

if __name__ == '__main__':
    for n in [n for n in SKITS if not sys.argv[1:] or n in sys.argv[1:]]:
        build(n)
