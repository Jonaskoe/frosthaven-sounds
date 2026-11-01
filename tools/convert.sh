#!/usr/bin/env bash
# Wandelt eine beliebige Audiodatei in eine Alexa-taugliche MP3 um.
#
#   ./tools/convert.sh [--trim] <eingabe> <event_type>
#
# - Zweipass-loudnorm auf etwa -16 LUFS, Spitzen auf -1 dBTP begrenzt
# - MP3, Stereo, 48 kbps, 24000 Hz, ohne Xing-Header
# - --trim entfernt Stille am Anfang und Ende
# Ergebnis: sounds/<event_type>.mp3
set -euo pipefail
export LC_ALL=C

TARGET_I=-16
TARGET_TP=-1
TARGET_LRA=11
SILENCE_DB=-50dB

usage() {
  echo "Verwendung: $0 [--trim] <eingabe> <event_type>" >&2
  echo "Beispiel:   $0 --trim raw/muenze.wav coin" >&2
  exit 2
}

trim=0
args=()
for a in "$@"; do
  case "$a" in
    --trim) trim=1 ;;
    -h|--help) usage ;;
    -*) echo "Unbekannte Option: $a" >&2; usage ;;
    *) args+=("$a") ;;
  esac
done
[ "${#args[@]}" -eq 2 ] || usage
input="${args[0]}"
event="${args[1]}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Fehler: ffmpeg ist nicht installiert oder nicht im PATH.
  macOS:          brew install ffmpeg
  Debian/Ubuntu:  sudo apt install ffmpeg
  Windows:        winget install ffmpeg  (oder WSL verwenden)
EOF
  exit 1
fi

[ -f "$input" ] || { echo "Fehler: Eingabedatei nicht gefunden: $input" >&2; exit 1; }

if ! [[ "$event" =~ ^[a-z0-9_]+$ ]]; then
  echo "Fehler: event_type darf nur a-z, 0-9 und _ enthalten: $event" >&2
  exit 1
fi

repo="$(cd "$(dirname "$0")/.." && pwd)"
out="$repo/sounds/$event.mp3"

if ! grep -q "\"event_type\": *\"$event\"" "$repo/sounds.json"; then
  echo "Warnung: '$event' steht noch nicht in sounds.json – check.sh wird das bemängeln." >&2
fi

pre=""
if [ "$trim" -eq 1 ]; then
  sr="silenceremove=start_periods=1:start_threshold=$SILENCE_DB:start_silence=0.05"
  pre="$sr,areverse,$sr,areverse,"
fi

echo "1/2 Lautheit messen …"
measure="$(ffmpeg -hide_banner -nostats -i "$input" -vn \
  -af "${pre}loudnorm=I=$TARGET_I:TP=$TARGET_TP:LRA=$TARGET_LRA:print_format=json" \
  -f null - 2>&1)"

val() { printf '%s\n' "$measure" | sed -n "s/.*\"$1\" *: *\"\([^\"]*\)\".*/\1/p" | tail -n1; }
in_i="$(val input_i)"; in_tp="$(val input_tp)"; in_lra="$(val input_lra)"
in_thresh="$(val input_thresh)"; offset="$(val target_offset)"

if [ -z "$in_i" ] || [ "$in_i" = "-inf" ]; then
  echo "Fehler: Lautheit konnte nicht gemessen werden (Datei leer oder nur Stille?)." >&2
  exit 1
fi
echo "   gemessen: ${in_i} LUFS, ${in_tp} dBTP"

echo "2/2 Normalisieren und kodieren …"
tmp="$(mktemp "${TMPDIR:-/tmp}/convert.XXXXXX.mp3")"
trap 'rm -f "$tmp"' EXIT

ffmpeg -hide_banner -loglevel error -y -i "$input" -vn -map_metadata -1 \
  -af "${pre}loudnorm=I=$TARGET_I:TP=$TARGET_TP:LRA=$TARGET_LRA:measured_I=$in_i:measured_TP=$in_tp:measured_LRA=$in_lra:measured_thresh=$in_thresh:offset=$offset:linear=true" \
  -ac 2 -codec:a libmp3lame -b:a 48k -ar 24000 -write_xing 0 "$tmp"

mkdir -p "$repo/sounds"
mv "$tmp" "$out"
trap - EXIT

dur="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$out" 2>/dev/null || true)"
echo "Fertig: sounds/$event.mp3 (${dur:-?} s)"
echo "Nächster Schritt: ./tools/check.sh"
