# ard-plus-dl

Hilfswerkzeug für [ARD-Plus-Abonnenten](https://www.ardplus.de/) zur lokalen Archivierung von Filmen, Serien und Tatort-Sammlungen - nur im Rahmen eines gültigen Abos und des geltenden Rechts.

Fork von [marco79cgn/ard-plus-dl](https://github.com/marco79cgn/ard-plus-dl) mit Batch-Verarbeitung, GraphQL-Integration und verbesserter Fehlerbehandlung.

> **Rechtlicher Hinweis:** Nur für die eigene, private Nutzung mit gültigem ARD-Plus-Abo. Keine Weitergabe heruntergeladener Inhalte. Details: [LEGAL.md](LEGAL.md)

## Features

- Filme, Serien und Tatort-Kategorien werden automatisch erkannt
- Mehrere Tonspuren und Untertitel, sofern verfügbar
- Interaktive Staffelauswahl oder `--automatic` für unbeaufsichtigte Abläufe
- Mehrere URLs aus einer Link-Datei (`--links-file`) - z. B. zum Fortsetzen unterbrochener Jobs
- Vorhandene Dateien werden übersprungen (`--force-redownload` zum Überschreiben)

## Voraussetzungen

Bash, [jq](https://jqlang.github.io/jq/), [yt-dlp](https://github.com/yt-dlp/yt-dlp), GNU-Tools (`curl`, `grep`, `awk`, `cut`, `sed`, `base64`, `tr`) und eine aktive [ARD-Plus-Mitgliedschaft](https://www.ardplus.de/).

## Installation

```bash
git clone https://github.com/chrmei/ard-plus-dl.git
cd ard-plus-dl
chmod 755 ard-plus-dl.sh
```

Nur das Skript:

```bash
curl -O https://raw.githubusercontent.com/chrmei/ard-plus-dl/refs/heads/main/ard-plus-dl.sh
chmod 755 ard-plus-dl.sh
```

## Verwendung

```bash
./ard-plus-dl.sh [--automatic] [--links-file <datei>] [--force-redownload] <url> <username> <password> [skip]
```

| Option / Parameter | Beschreibung |
|--------------------|--------------|
| `--automatic` | Alle Staffeln/Episoden ohne Rückfrage verarbeiten |
| `--links-file <datei>` | Mehrere URLs aus Datei (aktiviert `--automatic`) |
| `--force-redownload` | Vorhandene `.mp4`-Dateien erneut laden |
| `url` | ARD-Plus-Übersichtsseite (Film, Serie oder Tatort-Kategorie) |
| `username`, `password` | Eigene ARD-Plus-Zugangsdaten |
| `skip` | Optional: erste N Episoden überspringen (Standard: `1`) |

**Beispiele:**

```bash
# Serie (interaktiv) / Film / Tatort
./ard-plus-dl.sh 'https://www.ardplus.de/details/a0T0100000064DB-gegen-den-wind' user pass
./ard-plus-dl.sh 'https://www.ardplus.de/details/a0S01000000EWYi-lola-rennt' user pass
./ard-plus-dl.sh 'https://www.ardplus.de/kategorie/tatort-bremen' user pass

# Unbeaufsichtigt (eigene Inhalte, gültiges Abo vorausgesetzt)
./ard-plus-dl.sh --automatic 'https://www.ardplus.de/details/a0T0100000064DB-gegen-den-wind' user pass

# Mehrere URLs - eine pro Zeile, `#`-Kommentare erlaubt (siehe links.txt.example)
./ard-plus-dl.sh --links-file links.txt user pass
```

Unterbrochene Downloads einfach erneut starten - vorhandene Dateien werden übersprungen (`SKIP (already exists)` im Log). Bei `--links-file` entstehen Protokolle in `logs/` (`download_log_*`, `successful_links_*`, `failed_links_*`).

## Unterstützte URLs

| Typ | Beispiel-Pfad | Verhalten |
|-----|---------------|-----------|
| Film | `…/details/a0S01000000EWYi-lola-rennt` | Einzeldatei |
| Serie | `…/details/a0T0100000064DB-gegen-den-wind` | Staffeln/Episoden |
| Tatort | `…/kategorie/tatort-bremen` | Alle Folgen der Stadt |

## Ausgabe

Standard: `downloads/` neben der Link-Datei bzw. im Arbeitsverzeichnis. Anderes Ziel via `DOWNLOADS_DIR` (Docker: `/data/downloads`).

```text
downloads/Gegen den Wind/Season 01/Gegen den Wind S01E01 - Schönes Wochenende.mp4
downloads/Lola rennt (1998)/Lola rennt.mp4
```

## Docker (lokal bauen)

Es wird kein vorgefertigtes Container-Image veröffentlicht. Image lokal bauen und ausführen:

```bash
git clone https://github.com/chrmei/ard-plus-dl.git
cd ard-plus-dl
docker build -t ard-plus-dl .
docker run --rm -it -v "$(pwd)/:/data" ard-plus-dl download \
  'https://www.ardplus.de/details/a0T01000003LeBR-vorstadtweiber' "username" "password"
```

Windows: Host-Pfad mit Backslashes mounten, z. B. `-v C:\Users\Du\Videos:/data`.

## Lizenz & Attribution

Basiert auf [marco79cgn/ard-plus-dl](https://github.com/marco79cgn/ard-plus-dl), lizenziert unter [Unlicense](LICENSE). Erweiterungen in diesem Fork unter derselben Lizenz.
