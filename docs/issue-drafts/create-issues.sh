#!/bin/bash
# Files every issue draft in this directory as a GitHub issue.
# Requires: gh (authenticated with write access) and Issues enabled on the repo.
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for f in "$dir"/bug-*.md "$dir"/improvement-*.md; do
    title=$(head -n 1 "$f" | sed 's/^# //')
    labels=$(sed -n 's/^Labels: //p' "$f" | tr -d '`' | tr -d ' ')
    # Body without the title line and the trailing "Labels:" line.
    body=$(sed '1d' "$f" | sed '/^Labels: /d')
    args=(--title "$title" --body "$body")
    if [[ -n "$labels" ]]; then
        args+=(--label "$labels")
    fi
    echo "Creating issue: $title"
    if ! gh issue create "${args[@]}"; then
        echo "  Label(s) may not exist; retrying without labels..."
        gh issue create --title "$title" --body "$body"
    fi
done
