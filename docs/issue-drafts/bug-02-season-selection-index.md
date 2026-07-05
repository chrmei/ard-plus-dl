# Bug: Season selection treats the entered number as an array index, not the season number

## Description

The interactive season menu prints `seasonInSeries` as the selectable "Option", but the lookup uses the entered number as a **0-based array index** into the season list:

```bash
selectedSeasonId=$(echo "$seasonIds" | jq -r ".[$((selectedSeason - 1))].seasonId")
```

This only works when the seasons happen to be numbered 1..N contiguously. It breaks when:

- a series has no "season 1" on ARD Plus (e.g. seasons 2 and 3 only): choosing option `2` downloads season 3, choosing `3` fails with `null`;
- seasons have gaps (1, 2, 4).

The same mismatch affects `--automatic` mode, which generates `seq 1 $seasonCount` — the sequence 1..N is later interpreted as indices, so it accidentally works for automatic mode, but the count itself is computed from a field that does not exist (see below) and only works by coincidence.

Additionally, `seasonCount` is computed with a wrong field name (`.seasonId` under a key mapping that produces `{season: null}`):

```bash
seasonCount=$(echo "$contentResult" | jq '[.data.series.seasons.nodes[] | { season: .seasonId }] | length')
```

`.seasonId` does not exist on the node (`.id` does), so every entry is `{"season": null}` — `length` still yields the right number, but the expression is misleading and fragile.

## Reproduction

With a season list `[{season: 2, ...seasonId "aaa"}, {season: 3, ...seasonId "bbb"}]`, entering `2` at the prompt resolves to `bbb` (season 3) instead of `aaa`:

```bash
seasonIds='[{"season":2,"seasonId":"aaa","title":"S2"},{"season":3,"seasonId":"bbb","title":"S3"}]'
echo "$seasonIds" | jq -r ".[$((2 - 1))].seasonId"   # -> bbb (wrong)
```

## Suggested fix

Select by season number instead of index:

```bash
selectedSeasonId=$(echo "$seasonIds" | jq -r --argjson s "$selectedSeason" '.[] | select(.season == $s) | .seasonId')
```

and in `--automatic` mode iterate over the actual season numbers (`jq -r '.[].season'`) rather than `seq 1 $seasonCount`. Also validate that `selectedSeasonId` is non-empty/non-null before querying episodes, and fix the `seasonCount` jq expression (`.[] | length` on the nodes array directly).

Labels: `bug`
