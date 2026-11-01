#!/usr/bin/env bash
# Prüft alle MP3s in sounds/ auf die Alexa-Anforderungen und gleicht sie mit sounds.json ab.
#
#   ./tools/check.sh
#
# Fehler (Exit-Code 1):
#   - Abtastrate nicht 24000, 22050 oder 16000 Hz
#   - Bitrate nicht 48 kbps (±2 kbps), Codec nicht MP3
#   - Dauer über 10 s
#   - Dateiname nicht als event_type in sounds.json
#   - andere Dateien als .mp3 in sounds/
# Warnungen (kein Fehler):
#   - Einträge in sounds.json ohne Datei
#   - Dauer außerhalb von 0,5–3 s
set -euo pipefail
export LC_ALL=C
shopt -s nullglob

repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "Fehler: ffprobe (Teil von ffmpeg) ist nicht installiert." >&2
  exit 1
fi

errors=0
warnings=0
err()  { echo "FEHLER   $*"; errors=$((errors + 1)); }
warn() { echo "WARNUNG  $*"; warnings=$((warnings + 1)); }

[ -f sounds.json ] || { echo "Fehler: sounds.json fehlt." >&2; exit 1; }
if command -v jq >/dev/null 2>&1; then
  jq empty sounds.json || { echo "Fehler: sounds.json ist kein gültiges JSON." >&2; exit 1; }
  mapfile -t events < <(jq -r '.[].event_type' sounds.json)
else
  mapfile -t events < <(grep -o '"event_type": *"[^"]*"' sounds.json | sed 's/.*"\([^"]*\)"$/\1/')
fi

known() { local e; for e in "${events[@]}"; do [ "$e" = "$1" ] && return 0; done; return 1; }

for f in sounds/*; do
  name="$(basename "$f")"
  case "$name" in
    .gitkeep) continue ;;
    *.mp3) ;;
    *) err "$f: nur .mp3-Dateien gehören nach sounds/"; continue ;;
  esac

  event="${name%.mp3}"
  ok=1
  known "$event" || { err "$f: '$event' steht nicht als event_type in sounds.json"; ok=0; }

  info="$(ffprobe -v error -select_streams a:0 \
    -show_entries stream=codec_name,sample_rate,bit_rate:format=duration,bit_rate \
    -of default=nw=1 "$f" 2>&1)" || { err "$f: ffprobe kann die Datei nicht lesen"; continue; }

  get() { printf '%s\n' "$info" | sed -n "s/^$1=//p" | head -n1; }
  codec="$(get codec_name)"
  rate="$(get sample_rate)"
  # erste bit_rate = Stream, zweite = Format; Stream bevorzugen
  br="$(printf '%s\n' "$info" | sed -n 's/^bit_rate=//p' | grep -v '^N/A$' | head -n1)"
  dur="$(get duration)"

  [ "$codec" = "mp3" ] || { err "$f: Codec '$codec', erwartet mp3"; ok=0; }

  case "$rate" in
    24000|22050|16000) ;;
    *) err "$f: Abtastrate ${rate:-?} Hz, erlaubt sind 24000, 22050, 16000"; ok=0 ;;
  esac

  if [[ "$br" =~ ^[0-9]+$ ]]; then
    if [ "$br" -lt 46000 ] || [ "$br" -gt 50000 ]; then
      err "$f: Bitrate $((br / 1000)) kbps, erwartet 48 kbps (±2)"; ok=0
    fi
  else
    err "$f: Bitrate nicht ermittelbar"; ok=0
  fi

  if [[ "$dur" =~ ^[0-9.]+$ ]]; then
    if awk -v d="$dur" 'BEGIN { exit !(d > 10) }'; then
      err "$f: Dauer ${dur} s, höchstens 10 s"; ok=0
    elif awk -v d="$dur" 'BEGIN { exit !(d < 0.5 || d > 3) }'; then
      warn "$f: Dauer ${dur} s liegt außerhalb des Ziels 0,5–3 s"
    fi
  else
    err "$f: Dauer nicht ermittelbar"; ok=0
  fi

  [ "$ok" -eq 1 ] && printf 'OK       %s (%s Hz, %s kbps, %.2f s)\n' "$f" "$rate" "$((br / 1000))" "$dur"
done

missing=()
for e in "${events[@]}"; do
  [ -f "sounds/$e.mp3" ] || missing+=("$e")
done
if [ "${#missing[@]}" -gt 0 ]; then
  warn "noch keine Datei für ${#missing[@]} von ${#events[@]} Ereignissen: ${missing[*]}"
fi

echo
echo "Ergebnis: $errors Fehler, $warnings Warnungen"
[ "$errors" -eq 0 ]
