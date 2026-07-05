# Bug: Episode `skip` accumulates across seasons and skips one extra episode per season

## Description

When a `skip` value > 1 is passed, the per-season loop increments `episode_skip` once per season **before** it is used by `tail -n +$episode_skip`:

```bash
if [[ $episode_skip != "1" ]]; then
    log_msg "Überspringe $episode_skip Episode(n)."
    episode_skip=$((episode_skip + 1))
fi
...
done < <(echo "$episodes" | ... | tail -n +$episode_skip)
```

Because the increment happens inside the season loop and the variable is never reset, each subsequent season skips one more episode than the previous one.

## Reproduction

Verified with `episode_skip=2` over three seasons:

```text
season 1: tail -n +3 (skips 2 episodes)
season 2: tail -n +4 (skips 3 episodes)
season 3: tail -n +5 (skips 4 episodes)
```

There are two additional problems with the same code:

1. The log message is off by one relative to what actually happens: with `skip=2`, "Überspringe 2 Episode(n)" is printed but 2 episodes are skipped only in the first season (the parameter semantics of `skip` — default `1`, `tail -n +1` skips nothing — are confusing in themselves; see the README improvement issue).
2. Skipping is applied to **every selected season**, but a user resuming an interrupted run almost certainly wants to skip episodes only in the first (partially downloaded) season. Since the introduction of `skip_if_exists`, per-season skipping is largely redundant anyway.

## Suggested fix

Compute the `tail` offset in a local variable instead of mutating `episode_skip`, and only apply it to the first processed season (or drop the feature in favor of `skip_if_exists`):

```bash
local tail_from=$(( season_is_first ? episode_skip : 1 ))
... | tail -n +"$tail_from"
```

Labels: `bug`
