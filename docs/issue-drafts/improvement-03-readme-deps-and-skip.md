# Improvement: README — document missing dependencies (`ffmpeg`, `perl`, `column`) and the real `skip` semantics

## Description

Two documentation gaps that lead to avoidable support issues:

1. **Missing dependencies.** The README lists `bash`, `jq`, `yt-dlp` and GNU tools, but the script also needs:
   - **ffmpeg** — required by yt-dlp for `--merge-output-format mp4`, `bv+mergeall`, and `--embed-subs`. On Alpine/Docker it comes in as a yt-dlp dependency, but users installing yt-dlp via pip on a bare system will get merge failures.
   - **perl** — used to extract the `ld+json` payload in the Tatort path (it is installed in the Dockerfile, but not mentioned in the README requirements).
   - **column** (util-linux) — used for the season table; not part of coreutils on all distros (also explicitly installed in the Dockerfile).

2. **`skip` parameter semantics.** The README says "Optional: erste N Episoden überspringen (Standard: `1`)", which reads as "1 episode is skipped by default". In reality the value feeds `tail -n +$skip`, so the default `1` skips **nothing**, and due to the off-by-one adjustment in the script a value of `N` skips `N` episodes only in the first season (and currently one more per following season — tracked as a separate bug). The default should be documented as "no episodes skipped", or better, the parameter should be redefined as a plain count with `0` as default.

## Suggested fix

- Add ffmpeg, perl and column/util-linux to the "Voraussetzungen" section.
- Clarify (or redefine) the `skip` parameter and its default.

Labels: `documentation`
