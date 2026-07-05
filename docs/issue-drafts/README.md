# Issue drafts from repository review

GitHub Issues are currently **disabled** on this repository (default for forks).
To use these drafts:

1. Enable Issues: repository **Settings → General → Features → Issues**.
2. File all drafts at once with the [GitHub CLI](https://cli.github.com/):

   ```bash
   ./docs/issue-drafts/create-issues.sh
   ```

   Or file a single draft manually — the first line of each file is the title,
   the rest is the body:

   ```bash
   gh issue create --title "<first line without '# '>" --body-file <file>
   ```

## Contents

Bugs:

| File | Summary |
|------|---------|
| `bug-01-links-file-infinite-loop.md` | `--links-file` without a value hangs the script in an infinite loop |
| `bug-02-season-selection-index.md` | Season selection treats input as array index, not season number |
| `bug-03-episode-skip-accumulates.md` | Episode skip grows by one for every additional season |
| `bug-04-sed-mangles-titles.md` | `sed 's/\\"//g'` silently corrupts episode titles containing quotes |
| `bug-05-null-strings-in-filenames.md` | Literal `null` from `jq -r` leaks into file and directory names |
| `bug-06-filename-first-slash-only.md` | Only the first `/` in titles is replaced, creating stray subdirectories |
| `bug-07-tatort-temp-file-cwd.md` | Tatort mode leaves `current-tatort-episode.txt` behind in the working directory |
| `bug-08-token-handling.md` | Session token: weak validation, world-readable file, CWD-relative path |
| `bug-09-temp-file-leak-on-exit.md` | `content_result` temp file leaks on error exits |
| `bug-10-url-normalization-single-mode.md` | Single-URL mode does not normalize URLs (trailing slash / query string) |
| `bug-11-contenttype-mismatch.md` | `auth()`/`cleanup()` always send hard-coded, mismatched `contentType` values |

Improvements:

| File | Summary |
|------|---------|
| `improvement-01-shellcheck-hardening.md` | Fix shellcheck findings and add bash strict mode |
| `improvement-02-credentials-on-cli.md` | Avoid passing credentials as command-line arguments |
| `improvement-03-readme-deps-and-skip.md` | README: document `ffmpeg`/`perl` dependencies and real `skip` semantics |
| `improvement-04-dockerfile-single-run.md` | Dockerfile: collapse `apk add` chain into a single command |
