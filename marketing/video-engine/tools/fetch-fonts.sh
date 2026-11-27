#!/usr/bin/env bash
# Caches the brand fonts (all SIL OFL) in fonts/ for headless renders, which can't always reach Google Fonts
# directly (e.g. behind a TLS proxy). ugc2.html loads fonts/fonts.css first and falls back to Google Fonts.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p fonts
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
URL='https://fonts.googleapis.com/css2?family=TikTok+Sans:wght@600;700&family=Instrument+Serif:ital@0;1&family=DM+Sans:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap'
curl -sS -A "$UA" "$URL" > fonts/google.css
: > fonts/fonts.css
n=0
while IFS= read -r line; do
  if [[ "$line" =~ url\((https://[^\)]+)\) ]]; then
    src="${BASH_REMATCH[1]}"; n=$((n+1)); f="f$n.woff2"
    curl -sS -o "fonts/$f" "$src"
    line="${line//$src/$f}"
  fi
  printf '%s\n' "$line" >> fonts/fonts.css
done < fonts/google.css
rm fonts/google.css
echo "cached $n font files in fonts/"
