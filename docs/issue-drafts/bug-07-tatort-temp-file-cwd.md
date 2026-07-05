# Bug: Tatort mode writes `current-tatort-episode.txt` into the current directory and never deletes it

## Description

Movie/series metadata goes through a proper `mktemp` file (`$content_result`), and the season query creates and removes its own temp file. The Tatort loop, however, uses a **hard-coded relative path**:

```bash
if ! episodeDetailsStatus=$(fetch_graphql "MovieDetails" "$GRAPHQL_MOVIE_DETAILS" "$episode_variables" "current-tatort-episode.txt"); then
...
episodeDetails=$(cat current-tatort-episode.txt)
```

Consequences:

- the file is left behind in whatever directory the user launched the script from (it is not in `.gitignore` either, so it easily gets committed);
- running two instances of the script concurrently from the same directory makes them overwrite each other's episode metadata, mixing up movie IDs and download URLs;
- if the current directory is not writable, the Tatort path fails entirely.

## Suggested fix

Use `mktemp` like the other code paths and remove the file when the loop finishes (and in the existing `term`/exit cleanup):

```bash
tatort_result=$(mktemp)
...
rm -f "$tatort_result"
```

Labels: `bug`
