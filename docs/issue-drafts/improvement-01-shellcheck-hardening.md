# Improvement: fix shellcheck findings and add bash strict-mode hardening

## Description

`shellcheck -x ard-plus-dl.sh` currently reports ~24 findings. None are cosmetic-only; the recurring classes are:

- **SC2086 — unquoted variable expansions** (`echo $token`, `cat $content_result`, `rm -f $content_result`, `tail -n +$episode_skip`, `login $username $password`, …). Passwords or titles containing spaces/globs will word-split. `login $username $password` combined with a password containing spaces silently passes wrong credentials.
- **SC2125 — `downloadUrl=${videoUrl}?${urlParam}`** in three places: the unquoted `?` is a glob character; if a matching file exists in the CWD the assignment picks up the filename instead of the URL.
- **SC2162 — `read` without `-r`** in both episode loops: backslashes in JSON lines are eaten.
- **SC2034 — unused variables** (`deleteToken`, `seasonsStatus`, `episode_status`, `episodeDetailsStatus`): either check these results or drop the assignments.

Beyond shellcheck:

- The script has no `set -u` (or `set -o pipefail`); typos in variable names expand to empty strings and silently change behavior. Full `set -e` is probably too invasive for the retry logic, but `set -u -o pipefail` is low-risk.
- `curlBin=$(which curl)` is not checked; if curl is missing every request fails with a confusing "command not found". A startup dependency check for `curl`, `jq`, `yt-dlp`, `perl`, `column` with a clear error message would help (`command -v` is also preferred over `which`).
- Adding a GitHub Actions workflow that runs `shellcheck` on PRs would keep the script clean going forward.

## Suggested fix

1. Apply the shellcheck-suggested quoting fixes (mechanical).
2. Quote the three `downloadUrl` assignments: `downloadUrl="${videoUrl}?${urlParam}"`.
3. `while read -r episode_line` in both loops.
4. Add `set -u -o pipefail`, a dependency check, and a `shellcheck` CI workflow.

Labels: `enhancement`
