# Bug: single-URL mode skips URL normalization — trailing slash or query string breaks ID extraction

## Description

Batch mode normalizes each link (`normalize_url` strips fragments, whitespace and a trailing slash), but **single-URL mode passes `$ardPlusUrl` to `download_url` unmodified**. The ID extraction is purely positional:

```bash
showPath=$(echo "$ardPlusUrl" | rev | cut -d "/" -f1 | rev)
showId=$(echo "$showPath" | cut -d "-" -f1)
```

Failure cases (verified):

- `.../details/a0S01000000EWYi-lola-rennt/` (trailing slash) → `showPath` is empty → GraphQL lookup fails with a generic error.
- `.../details/a0S01000000EWYi-lola-rennt?utm_source=share` (query string, typical when copying share links) → `showId` is extracted, but for URLs where the query precedes no `-` (e.g. `...?foo-bar`) or in the Tatort path (`showPath` is reused verbatim to build `https://www.ardplus.de/kategorie/$showPath`), the request goes to a wrong URL.
- URL fragments (`#...`) are only stripped in batch mode.

`normalize_url` itself also does not strip query strings (`?...`), so even batch mode is affected by share links.

## Suggested fix

Apply `normalize_url` in single mode too, and extend it to cut query strings:

```bash
normalize_url() {
    local url="$1"
    url="${url%%#*}"
    url="${url%%\?*}"
    ...
}
...
if download_url "$(normalize_url "$ardPlusUrl")" "$skip"; then
```

Additionally, consider validating that `showId` is non-empty before issuing the GraphQL request, so the user gets an actionable "could not parse content ID from URL" error instead of a retry-exhausted GraphQL failure.

Labels: `bug`
