# Bug: `auth()` and `cleanup()` send hard-coded, mutually inconsistent `contentType` values

## Description

The playback-token request always claims the content is an episode, while the token-delete request always claims it is a movie — regardless of what is actually being downloaded:

```bash
# auth(): always CmsEpisode
--data-raw "{\"contentId\":\"$movieId\",\"contentType\":\"CmsEpisode\",...}"

# cleanup(): always CmsMovie
--data-raw "{\"contentId\":\"$movieId\",\"contentType\":\"CmsMovie\"}"
```

So for a movie download the session is *created* as `CmsEpisode` but *deleted* as `CmsMovie` (and vice versa for episodes). If the backend keys playback sessions on `(contentId, contentType)`, the delete call never matches the session that was created, and the account keeps accumulating "active playback" sessions until it hits the concurrent-stream limit — which manifests as `authorizationParams: null` failures after a number of downloads.

Related robustness issues in the same functions:

- `auth()` does not check the HTTP status or the response shape; on a 401/5xx, `jq -r '.authorizationParams'` on an error body returns `null` and the caller only sees the generic "missing playback authorization" message. Distinguishing "session expired → re-login and retry" from "no entitlement" would make batch runs far more resilient.
- The JSON bodies are assembled by string interpolation; `movieId` comes from API responses today, but building them with `jq -n --arg` would be safer and consistent with `fetch_graphql`.
- `cleanup()`'s response is captured into `deleteToken` and never checked (shellcheck SC2034).

## Suggested fix

Track the actual content type alongside `movieId` (e.g. set `contentType=CmsMovie` in the movie/Tatort paths and `CmsEpisode` in the series path) and pass it to both `auth()` and `cleanup()`; build the payloads with `jq -n`.

Labels: `bug`
