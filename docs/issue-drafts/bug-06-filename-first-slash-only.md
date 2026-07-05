# Bug: only the first `/` in titles is sanitized, later slashes create unintended subdirectories

## Description

Titles are sanitized with the single-substitution form of bash parameter expansion:

```bash
filename="${name/\// } (${year})/${name/\// }"
filename="${requestedShow/\// }/Season ${selectedSeasonFormatted}/..."
```

`${var/pattern/repl}` replaces only the **first** occurrence. A title like `Titel 1/2/3` becomes `Titel 1 2/3`, so yt-dlp creates an extra directory level `Titel 1 2/` and writes `3.mp4` inside it — the skip-existing logic then also looks at the wrong path.

Verified:

```bash
name='A/B/C'; echo "${name/\// }"   # -> "A B/C"  (second slash survives)
echo "${name//\// }"                # -> "A B C"
```

Additionally, the Tatort filename (`Tatort ${city} (${team}) - Folge ${episode} - ${name} (${year})`) never sanitizes slashes in `name`, `team` or `city` at all.

## Suggested fix

Use the global substitution form everywhere a title is embedded in a path, ideally via a small helper so all three code paths (movie, series, Tatort) share the same sanitization:

```bash
sanitize() { local s="${1//\// }"; printf '%s' "$s"; }
```

Consider also stripping other characters that are problematic on common target filesystems (e.g. `:` on SMB/NTFS mounts), since downloads often land on a NAS.

Labels: `bug`
