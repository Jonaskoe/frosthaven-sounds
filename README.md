# Frosthaven Sounds

Kurze MP3-Soundeffekte für Frosthaven-Ereignisse. GitHub Pages stellt sie öffentlich per HTTPS bereit.
Home Assistant spielt sie per SSML-`<audio>`-Tag über
[Alexa Media Player](https://github.com/alandtse/alexa_media_player) auf Echo-Lautsprechern ab.
Amazons Cloud lädt die Dateien selbst herunter, deshalb müssen sie öffentlich erreichbar sein.

Dieses Repository enthält nur Sounds, Doku und Werkzeuge: keine Tokens, internen Adressen oder HA-Konfiguration.

- **Vorhörseite:** <https://jonaskoe.github.io/frosthaven-sounds/>
- **Manifest:** <https://jonaskoe.github.io/frosthaven-sounds/sounds.json>

## URL-Schema

```
https://jonaskoe.github.io/frosthaven-sounds/sounds/<event_type>.mp3
```

Beispiel: `https://jonaskoe.github.io/frosthaven-sounds/sounds/coin.mp3`

Alle Dateien liegen flach in `sounds/`. Der Dateiname ohne `.mp3` ist der `event_type`.

## Ereignisse

### Angriffsmodifikatoren (Monster-Deck, bewertet aus Spielersicht)

| event_type | Label | Bewertung | Bemerkung |
|---|---|---|---|
| `double` | Doppelt (2x) | sehr schlecht | löst Mischen aus |
| `plus2` | +2 | schlecht | |
| `plus1` | +1 | schlecht | eher schlecht |
| `plus0` | +0 | neutral | |
| `minus1` | -1 | gut | eher gut |
| `minus2` | -2 | gut | |
| `null` | Null | sehr gut | löst Mischen aus |
| `bless` | Segen | sehr schlecht | beim Monster |
| `curse` | Fluch | sehr gut | beim Monster |

### Beute

| event_type | Label |
|---|---|
| `coin` | Münze |
| `lumber` | Holz |
| `metal` | Metall |
| `hide` | Leder |
| `arrowvine` | Pfeilranke |
| `axenut` | Axtnuss |
| `corpsecap` | Leichenkappe |
| `flamefruit` | Flammenfrucht |
| `snowthistle` | Schneedistel |
| `rockroot` | Steinwurz |
| `treasure` | Schatz |
| `special_1418` | Sonderkarte 1418 |
| `special_1419` | Sonderkarte 1419 |

Die sechs Kräuter und die beiden Sonderkarten teilen sich einen Sound (`group` in `sounds.json`).
Jedes Ereignis behält seine eigene URL `sounds/<event_type>.mp3`, das Home-Assistant-Skript bleibt also gleich.

Die maßgebliche Liste ist [`sounds.json`](sounds.json). Jeder Eintrag hat diese Felder:

| Feld | Inhalt |
|---|---|
| `event_type` | Dateiname ohne `.mp3` |
| `category` | `modifier` oder `loot` |
| `label` | deutscher Anzeigename |
| `rating` | nur bei Modifikatoren: `very_bad`, `bad`, `neutral`, `good`, `very_good` |
| `file` | `sounds/<event_type>.mp3` |
| `description` | kurze Beschreibung, darf leer sein |
| `group` | optional: Einträge mit gleichem Wert teilen sich einen Sound und erscheinen auf der Vorhörseite als eine Zeile |

## Alexa-Anforderungen

Alexa spielt SSML-`<audio>` nur ab, wenn die Datei diese Bedingungen erfüllt:

- **Format:** MP3, **48 kbps**
- **Abtastrate:** **24000 Hz** (erlaubt sind auch 22050 und 16000 Hz)
- **Länge:** höchstens 240 s pro Antwort. Ziel hier: **0,5–3 s** pro Sound
- **Adresse:** öffentliche **HTTPS-URL** mit gültigem Zertifikat. GitHub Pages erfüllt das.

`tools/convert.sh` erzeugt genau dieses Format. `tools/check.sh` prüft es:
Abtastrate, Bitrate ±2 kbps, Dauer höchstens 10 s und Eintrag in `sounds.json`.
Die GitHub Action [`check-sounds.yml`](.github/workflows/check-sounds.yml) führt die Prüfung bei jedem Push
und Pull Request aus.

## Neuen Sound hinzufügen

Voraussetzung: `ffmpeg` ist installiert (`brew install ffmpeg` oder `sudo apt install ffmpeg`).

1. **Original ablegen:** Datei nach `raw/` kopieren. `raw/` wird nicht committet.
2. **Konvertieren:**
   ```sh
   ./tools/convert.sh --trim raw/muenze.wav coin
   ```
   Das normalisiert per Zweipass-loudnorm auf etwa -16 LUFS, begrenzt die Spitzen auf -1 dBTP
   und schreibt `sounds/coin.mp3` (Stereo, 48 kbps, 24000 Hz).
   `--trim` entfernt Stille am Anfang und Ende.
3. **Prüfen:**
   ```sh
   ./tools/check.sh
   ```
   Fehlende Sounds erscheinen nur als Warnung. Echte Verstöße führen zu Exit-Code ≠ 0.
4. **Herkunft eintragen:** In [`CREDITS.md`](CREDITS.md) Quelle, Urheber, Lizenz und Änderungen ergänzen.
5. **Committen und pushen:**
   ```sh
   git add sounds/coin.mp3 CREDITS.md
   git commit -m "Sound coin hinzufügen"
   git push
   ```
   Nach etwa einer Minute ist die Datei über GitHub Pages erreichbar.

Ein **neues Ereignis** braucht zusätzlich einen Eintrag in `sounds.json` und in der Tabelle oben.
Optional die Auswahlliste im HA-Skript ergänzen.

Zum Vorhören die [Vorhörseite](https://jonaskoe.github.io/frosthaven-sounds/) öffnen.
Sie zeigt bei jedem Sound auch Quelle, Urheber und Lizenz an. Diese Angaben liest sie aus `CREDITS.md`.
Lokal funktioniert sie nur über einen Webserver, z. B. `python3 -m http.server`, dann <http://localhost:8000>.

## Home Assistant

Das vollständige Skript steht in [`homeassistant/alexa_sound_script.yaml`](homeassistant/alexa_sound_script.yaml).
Der Kern:

```yaml
alexa_sound:
  alias: Alexa-Sound abspielen
  mode: queued
  fields:
    geraet:
      name: Gerät
      required: true
      selector:
        entity:
          domain: media_player
    sound:
      name: Sound
      required: true
      selector:
        text:
  sequence:
    - action: notify.alexa_media
      data:
        message: "<audio src='https://jonaskoe.github.io/frosthaven-sounds/sounds/{{ sound }}.mp3'/>"
        target: "{{ geraet }}"
        data:
          type: tts   # nötig: mit announce bleibt der Echo bei SSML-Audio stumm
```

Aufruf aus einer Automation:

```yaml
actions:
  - action: script.alexa_sound
    data:
      geraet: media_player.echo_wohnzimmer
      sound: coin
```

Hinweis zu `null`: In YAML immer in Anführungszeichen schreiben (`sound: "null"`).
Sonst liest Home Assistant einen leeren Wert statt des Textes `null`.

## Cache

Alexa kann Audiodateien zwischenspeichern. Wer einen Sound ersetzt, hört unter Umständen noch eine Weile
die alte Version. Abhilfe:

- den neuen Sound unter einem **neuen Dateinamen** ablegen, oder
- eine Version an die URL hängen, z. B. `.../sounds/coin.mp3?v=2`.

Auch GitHub Pages liefert Dateien mit Cache-Headern von etwa 10 Minuten aus.

## Lizenzen

Jeder Sound hat seine eigene Lizenz, siehe [`CREDITS.md`](CREDITS.md). Deshalb gibt es keine gemeinsame LICENSE-Datei.
