# Bug: literal `null` from `jq -r` leaks into file names and directory names

## Description

`jq -r` prints the string `null` for missing JSON fields. Several places build file names from such values without checking:

1. **Movie year** — `year=$(echo "$movie" | jq -r '.productionYear')`; if `productionYear` is missing, the folder becomes `Movie Title (null)/Movie Title.mp4`.
2. **Tatort team** — the null check uses `-n`, which is **always true** for the string `null`:

   ```bash
   team=$(echo "$customData" | jq -r '.team')
   ...
   if [[ -n "$team" ]]; then
       filename="$filename (${team})"
   fi
   ```

   A missing team produces `Tatort Köln (null) - ...`. (Verified: `jq -r '.team'` on `{"team":null}` returns the 4-character string `null`, so `[[ -n "$team" ]]` passes.)
3. **Tatort city/year** — `city` and `year` are used unconditionally; `customData` itself may be `null`, in which case the subsequent `jq` calls on it fail and every field becomes empty/null.
4. **Episode title / number** — `name` and `episode` in the series loop are also used unchecked (`E$(printf '%02d' $episode)` even errors out on `null` with `printf: null: invalid number`).

Note the inconsistency: the `episode` field *is* checked with `[[ "$episode" != null ]]` two lines below the `team` check — the same pattern should be applied everywhere.

## Suggested fix

Use jq's alternative operator to default to empty and test consistently:

```bash
team=$(echo "$customData" | jq -r '.team // empty')
year=$(echo "$movie" | jq -r '.productionYear // empty')
[[ -n "$team" ]] && filename="$filename (${team})"
[[ -n "$year" ]] && dirname="${name} (${year})" || dirname="${name}"
```

Labels: `bug`
