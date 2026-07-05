# Bug: `content_result` temp file leaks on error exits; cleanup trap only covers SIGINT

## Description

A temp file is created early (`content_result=$(mktemp)`) and removed only:

- in the `term()` handler, which is bound to **SIGINT only** (`trap term SIGINT`), and
- at the very last line of the script (`rm -f $content_result`).

Any other exit path leaks the file, e.g.:

- `exit 1` in `ensure_token` on login failure,
- `exit 1` in single-URL mode when `download_url` fails (line `exit 1` before the final `rm`),
- the script being killed by SIGTERM/SIGHUP (e.g. `docker stop`, closing the terminal).

In batch/Docker usage this accumulates stale files in `/tmp` over time. The same applies to the per-season `mktemp` files if the process dies mid-season, and to `current-tatort-episode.txt` (tracked separately).

A second, related problem: `term()` exits with status `0` after CTRL+C, so callers (cron, CI, wrapper scripts) cannot distinguish an aborted run from a successful one. The conventional exit code for SIGINT is `130`.

## Suggested fix

Use an EXIT trap, which fires for normal exits and (in combination with signal traps) terminating signals:

```bash
cleanup_tmp() { rm -f "$content_result"; }
trap cleanup_tmp EXIT
trap 'echo "CTRL+C pressed. Cleanup and exit!"; cleanup; exit 130' INT TERM
```

Labels: `bug`
