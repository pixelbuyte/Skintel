#!/usr/bin/env bash
# Clean a raw voiceover take and mux it onto a rendered Skintel video.
#
#   ./add-vo.sh <video.mp4> <voice.(m4a|wav|mp3)> <output.mp4> [music.mp3]
#
#   TTS=1 ./add-vo.sh ...   for synthesised voice (ElevenLabs et al.)
#
# Mic recordings get the full repair chain: high-pass → de-ess → compression → -14 LUFS.
# TTS output is already clean and evenly levelled, so TTS=1 skips straight to loudness
# normalisation — running repair processing over synthetic speech only flattens it
# further and is a large part of why AI voiceovers read as "AI voiceover".
#
# Music, if given, is ducked well under the voice and faded out at the end.
# Video is stream-copied, so the picture is never re-encoded.

set -euo pipefail

VIDEO=${1:?usage: add-vo.sh <video.mp4> <voice> <output.mp4> [music]}
VOICE=${2:?missing voice track}
OUT=${3:?missing output path}
MUSIC=${4:-}

for f in "$VIDEO" "$VOICE" ${MUSIC:+"$MUSIC"}; do
  [ -f "$f" ] || { echo "not found: $f" >&2; exit 1; }
done

# Length of the picture — audio is trimmed to match so nothing runs past the last frame.
DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$VIDEO")
echo "video: ${DUR}s"

# --- voice chain ---------------------------------------------------------------
#  highpass  80Hz : removes room rumble, handling noise, AC hum
#  deesser        : tames harsh S sounds, the giveaway of close phone recording
#  compand        : gentle levelling so quiet phrases stay audible on a phone speaker
#  loudnorm       : -14 LUFS integrated, matching TikTok/IG/YouTube normalisation
if [ "${TTS:-0}" = "1" ]; then
  echo "mode: synthesised voice (loudness only)"
  # LRA=14 preserves what little dynamic range the model produced. Squashing it
  # is what turns a decent TTS read into an obvious one.
  VOICE_CHAIN="loudnorm=I=-14:TP=-1.5:LRA=14"
else
  echo "mode: mic recording (full repair chain)"
  VOICE_CHAIN="highpass=f=80,deesser=i=0.4,\
compand=attacks=0.02:decays=0.25:points=-70/-70|-32/-16|-14/-10|0/-7:gain=2,\
loudnorm=I=-14:TP=-1.5:LRA=11"
fi

if [ -z "$MUSIC" ]; then
  ffmpeg -y -v warning -stats \
    -i "$VIDEO" -i "$VOICE" \
    -filter_complex "[1:a]${VOICE_CHAIN},apad,atrim=0:${DUR},asetpts=N/SR/TB[a]" \
    -map 0:v -map "[a]" \
    -c:v copy -c:a aac -b:a 192k -ar 48000 \
    "$OUT"
else
  # Music sits ~18 dB under the voice and fades over the final 1.5s.
  FADE_START=$(awk -v d="$DUR" 'BEGIN{printf "%.2f", (d>1.5? d-1.5 : 0)}')
  ffmpeg -y -v warning -stats \
    -i "$VIDEO" -i "$VOICE" -i "$MUSIC" \
    -filter_complex "\
      [1:a]${VOICE_CHAIN},apad,atrim=0:${DUR},asetpts=N/SR/TB[vo]; \
      [2:a]volume=-18dB,afade=t=out:st=${FADE_START}:d=1.5,apad,atrim=0:${DUR},asetpts=N/SR/TB[bed]; \
      [vo][bed]amix=inputs=2:duration=first:dropout_transition=0:normalize=0,\
      loudnorm=I=-14:TP=-1.5:LRA=11[a]" \
    -map 0:v -map "[a]" \
    -c:v copy -c:a aac -b:a 192k -ar 48000 \
    "$OUT"
fi

echo "→ $OUT"
ffprobe -v error -show_entries stream=codec_type,codec_name -of default=nw=1 "$OUT"
