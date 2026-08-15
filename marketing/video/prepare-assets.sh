#!/usr/bin/env bash
# Crop the iPhone frames out of designs/previews/*.png into ./assets/.
#
# The preview PNGs carry a design-note caption strip under each device, and the
# device sits inset from the sheet edges. The compositions expect a bare
# 770x1710 phone, so every source is cropped to the same window. Output is
# gitignored — it is derived, and regenerating takes about a second.
#
#   ./prepare-assets.sh

set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC="$HERE/../../designs/previews"
OUT="$HERE/assets"

command -v ffmpeg >/dev/null || { echo "ffmpeg not found" >&2; exit 1; }
[ -d "$SRC" ] || { echo "missing $SRC — run from a full checkout" >&2; exit 1; }

mkdir -p "$OUT"

# Phone frame bounds within the 786px-wide preview sheets.
CROP="crop=770:1710:8:6"

# Every portrait surface the compositions reference. icon.png and widgets.png are
# landscape boards, not phones, so they are deliberately excluded.
SCREENS=(home verdict scan journal product culprits routine splash compare paywall ob2 found login)

for name in "${SCREENS[@]}"; do
  src="$SRC/$name.png"
  if [ ! -f "$src" ]; then
    echo "skip $name (not in designs/previews)" >&2
    continue
  fi
  ffmpeg -y -v error -i "$src" -vf "$CROP" "$OUT/$name.png"
  echo "  $name.png"
done

echo "→ $OUT"
