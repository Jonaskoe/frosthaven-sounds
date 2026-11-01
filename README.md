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

Alle 22 Ereignisse haben einen Sound. Herkunft, Urheber und Lizenz stehen in [`CREDITS.md`](CREDITS.md)
und auf der [Vorhörseite](https://jonaskoe.github.io/frosthaven-sounds/).

### Angriffsmodifikatoren (Monster-Deck, bewertet aus Spielersicht)

| event_type | Label | Bewertung | Bemerkung | Sound |
|---|---|---|---|---|
| `double` | Doppelt (2x) | sehr schlecht | löst Mischen aus | Schmerzensschrei |
| `plus2` | +2 | schlecht | | Schwertklirren |
| `plus1` | +1 | schlecht | eher schlecht | Schwertklirren |
| `plus0` | +0 | neutral | | Schwertklirren (anderes) |
| `minus1` | -1 | gut | eher gut | Schwertschlag |
| `minus2` | -2 | gut | | Schwertschlag |
| `null` | Null | sehr gut | löst Mischen aus | Lachen |
| `bless` | Segen | sehr schlecht | beim Monster | Schmerzensschrei |
| `curse` | Fluch | sehr gut | beim Monster | Lachen |

Vereinfacht: Je zwei Modifikatoren mit ähnlicher Wirkung teilen sich einen Sound.

### Beute

| event_type | Label | Sound |
|---|---|---|
| `coin` | Münze | rollende Münze |
| `lumber` | Holz | Holzstück |
| `metal` | Metall | Eisenklicken |
| `hide` | Leder | knarzendes Leder |
| `arrowvine` | Pfeilranke | kleiner Gegenstand* |
| `axenut` | Axtnuss | kleiner Gegenstand* |
| `corpsecap` | Leichenkappe | kleiner Gegenstand* |
| `flamefruit` | Flammenfrucht | kleiner Gegenstand* |
| `snowthistle` | Schneedistel | kleiner Gegenstand* |
| `rockroot` | Steinwurz | kleiner Gegenstand* |
| `treasure` | Schatz | Gewinn-Jingle (4,6 s) |
| `special_1418` | Sonderkarte 1418 | kleiner Gegenstand* |
| `special_1419` | Sonderkarte 1419 | kleiner Gegenstand* |

\* Die sechs Kräuter und die beiden Sonderkarten teilen sich einen Sound (`group` in `sounds.json`)
und erscheinen auf der Vorhörseite als eine Zeile „Kräuter und Sonderkarten“.

Auch bei gemeinsamen Sounds hat jedes Ereignis seine eigene Datei und URL `sounds/<event_type>.mp3`.
Die Dateien sind dann einfach identisch. So bleibt das Home-Assistant-Skript gleich.

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
- **Länge:** höchstens 240 s pro Antwort. Ziel hier: **0,5–3 s** pro Sound (der Schatz-Jingle ist mit 4,6 s bewusst länger)
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

   Sonderfälle, jeweils vorher mit `ffmpeg` eine Zwischendatei in `raw/` erzeugen:
   - **Lange Aufnahme, nur ein Teil wird gebraucht:** Ausschnitt schneiden, z. B. 3,8–6,5 s mit kurzem Ausblenden:
     ```sh
     ffmpeg -ss 3.8 -t 2.7 -i raw/schrei.m4a -af "afade=t=out:st=2.5:d=0.2" raw/schrei_cut.wav
     ```
   - **Sehr kurzer Sound (unter etwa 0,4 s):** Die Lautheitsmessung schlägt dann fehl
     („Lautheit konnte nicht gemessen werden“). Mit Stille auf 0,6 s verlängern und **ohne** `--trim` konvertieren:
     ```sh
     ffmpeg -i raw/klick.wav -af "apad=whole_dur=0.6" raw/klick_pad.wav
     ./tools/convert.sh raw/klick_pad.wav metal
     ```
   - **Ein Sound für mehrere Ereignisse:** `convert.sh` einmal pro `event_type` aufrufen.
     Sollen sie auf der Vorhörseite als eine Zeile erscheinen, in `sounds.json` dasselbe `group` setzen.
3. **Prüfen:**
   ```sh
   ./tools/check.sh
   ```
   Fehlende Sounds erscheinen nur als Warnung. Echte Verstöße führen zu Exit-Code ≠ 0.
4. **Herkunft eintragen:** In [`CREDITS.md`](CREDITS.md) Quelle, Urheber, Lizenz und Änderungen ergänzen.
   Die Vorhörseite übernimmt die Angaben von dort automatisch.
5. **Committen und auf `main` bringen:**
   ```sh
   git add sounds/coin.mp3 CREDITS.md
   git commit -m "Sound coin hinzufügen"
   git push
   ```
   GitHub Pages veröffentlicht nur `main`. Wer auf einem eigenen Branch arbeitet, mergt per Pull Request.
   Ein bis zwei Minuten nach dem Push auf `main` ist die Datei über GitHub Pages erreichbar.

Ein **neues Ereignis** braucht zusätzlich einen Eintrag in `sounds.json`, eine Zeile in `CREDITS.md`
und eine Zeile in der passenden Tabelle oben. Optional die Auswahlliste im HA-Skript ergänzen.

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
