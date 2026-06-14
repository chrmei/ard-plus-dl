# ard-plus-dl

Kleines Bash-Skript zum Herunterladen von Videos von [ARD Plus](https://www.ardplus.de/) — Filme, Serien und Tatort-Sammlungen.

![Screenshot](https://user-images.githubusercontent.com/9810829/293396091-2b2a6fc9-91ab-43f6-81c4-670bcd4762f1.png)

## Features

- Automatische Erkennung von Filmen, Serien und Tatort-Kategorien
- Mehrere Tonspuren (z. B. Deutsch & Englisch) und eingebettete Untertitel, sofern verfügbar
- Interaktive Staffelauswahl oder vollautomatischer Download aller Staffeln
- Batch-Download mehrerer URLs aus einer Link-Datei
- Überspringen bereits vorhandener Dateien (Standard; mit `--force-redownload` deaktivierbar)
- Fortsetzen unterbrochener Downloads (einzelne URL mit `skip`-Parameter)

## Voraussetzungen

- Bash (z. B. macOS Terminal oder Linux)
- [jq](https://jqlang.github.io/jq/)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- GNU-Tools: `curl`, `grep`, `awk`, `cut`, `sed`, `base64`, `tr`
- Aktive ARD-Plus-[Mitgliedschaft](https://www.ardplus.de/)

## Installation

Skript herunterladen und ausführbar machen:

```bash
curl -O https://raw.githubusercontent.com/marco79cgn/ard-plus-dl/refs/heads/main/ard-plus-dl.sh
chmod 755 ard-plus-dl.sh
```

Alternativ per Git:

```bash
git clone https://github.com/marco79cgn/ard-plus-dl.git
cd ard-plus-dl
chmod 755 ard-plus-dl.sh
```

## Verwendung

### Einzelne URL

```bash
./ard-plus-dl.sh <url> <username> <password> [skip]
```

| Parameter   | Beschreibung |
|-------------|--------------|
| `url`       | Übersichtsseite eines Films, einer Serie oder einer Tatort-Kategorie auf ARD Plus |
| `username`  | ARD-Plus-Benutzername |
| `password`  | ARD-Plus-Passwort |
| `skip`      | Optional. Anzahl bereits geladener Episoden zum Überspringen (Standard: `1` = keine überspringen) |

**Beispiele:**

```bash
# Serie — Staffeln werden interaktiv zur Auswahl angeboten
./ard-plus-dl.sh 'https://www.ardplus.de/details/a0T0100000064DB-gegen-den-wind' user pass

# Film — wird sofort geladen
./ard-plus-dl.sh 'https://www.ardplus.de/details/a0S01000000EWYi-lola-rennt' user pass

# Tatort — alle Folgen einer Stadt
./ard-plus-dl.sh 'https://www.ardplus.de/kategorie/tatort-bremen' user pass
```

### Automatischer Modus (`--automatic`)

Ohne Rückfragen alle Staffeln bzw. Episoden laden:

```bash
./ard-plus-dl.sh --automatic <url> <username> <password> [skip]
```

Bei Serien werden automatisch alle Staffeln und alle Episoden heruntergeladen. Bricht der Download ab, kann das Skript erneut gestartet werden — vorhandene `.mp4`-Dateien werden standardmäßig erkannt und übersprungen (im Log als `SKIP (already exists)`). Alternativ kann der `skip`-Parameter genutzt werden, um die ersten N Episoden zu überspringen. Mit `--force-redownload` werden auch vorhandene Dateien erneut geladen.

### Batch-Download (`--links-file`)

Mehrere Titel nacheinander aus einer Textdatei laden. Pro Zeile eine ARD-Plus-URL; Zeilen, die mit `#` beginnen, und Leerzeilen werden ignoriert.

```bash
./ard-plus-dl.sh --links-file links.txt <username> <password>
```

Eine Beispieldatei liegt als [`links.txt.example`](links.txt.example) im Repository:

```text
# Ein Film
https://www.ardplus.de/details/a0S01000000EWYi-lola-rennt

# Eine Serie — alle Staffeln und Episoden werden geladen
https://www.ardplus.de/details/a0T0100000064DB-gegen-den-wind
```

`--links-file` schaltet automatisch den `--automatic`-Modus ein. Pro URL reicht die Übersichtsseite — separate Zeilen pro Staffel sind nicht nötig.

**Protokolldateien** (im Unterverzeichnis `logs/` neben `links.txt`):

| Datei | Inhalt |
|-------|--------|
| `logs/successful_links_<timestamp>.txt` | Erfolgreich geladene URLs |
| `logs/failed_links_<timestamp>.txt` | Fehlgeschlagene URLs mit Fehlergrund (Tab-getrennt) |
| `logs/download_log_<timestamp>.txt` | Vollständiges Ausführungsprotokoll |

Das Skript gibt beim Start und Ende den Pfad zum `logs/`-Verzeichnis aus. Protokolldateien dienen nur der Dokumentation — beim erneuten Start wird jede URL in `links.txt` erneut geprüft. Vorhandene vollständige `.mp4`-Dateien werden übersprungen (`SKIP (already exists)` im Log), fehlende oder unvollständige Episoden werden nachgeladen.

## Unterstützte Inhalte

| Typ | URL-Beispiel | Verhalten |
|-----|--------------|-----------|
| **Film** | `…/details/a0S01000000EWYi-lola-rennt` | Einzeldatei |
| **Serie** | `…/details/a0T0100000064DB-gegen-den-wind` | Alle Staffeln und Episoden (interaktiv oder mit `--automatic`) |
| **Tatort** | `…/kategorie/tatort-bremen` | Alle Episoden der jeweiligen Stadt |

## Ausgabe

Dateien werden im Verzeichnis `downloads/` (neben `links.txt` bzw. im aktuellen Arbeitsverzeichnis) in sinnvolle Ordnerstrukturen sortiert und benannt, z. B.:

```text
downloads/Gegen den Wind/Season 01/Gegen den Wind S01E01 - Schönes Wochenende.mp4
downloads/Lola rennt (1998)/Lola rennt.mp4
```

Über die Umgebungsvariable `DOWNLOADS_DIR` kann ein anderer Zielpfad gesetzt werden (im Docker-Image standardmäßig `/data/downloads`).

## Docker

Image lokal bauen und ausführen:

```bash
git clone https://github.com/marco79cgn/ard-plus-dl.git
cd ard-plus-dl
docker build -t ard-plus-dl .
docker run --rm -it -v "$(pwd)/:/data" ard-plus-dl download \
  'https://www.ardplus.de/details/a0T01000003LeBR-vorstadtweiber' "username" "password"
```

Unter Windows das lokale Verzeichnis mit Backslashes mounten:

```bash
docker run --rm -it -v C:\Users\marco\movies:/data ard-plus-dl download '<url>' "username" "password"
```

Alternativ das vorgefertigte Image von GitHub Container Registry nutzen — ohne lokale Installation:

```bash
docker run --rm -it -v "$(pwd)/:/data" ghcr.io/marco79cgn/ard-plus-dl download '<url>' "username" "password"
```

Downloads landen im gemounteten Host-Verzeichnis (`/data` im Container).
