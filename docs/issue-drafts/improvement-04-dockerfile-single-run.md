# Improvement: Dockerfile cleanups

## Description

Minor issues in the current `Dockerfile`:

1. Six chained `apk add --no-cache` invocations in one `RUN`; a single invocation is shorter and marginally faster:

   ```dockerfile
   RUN apk add --no-cache bash curl yt-dlp jq util-linux perl
   ```

2. `chmod +x /usr/bin/download` operates on a **symlink**, so it actually chmods the target `/app/ard-plus-dl.sh` — that works, but only because the script is committed with the executable bit set. Making it explicit (`chmod +x /app/ard-plus-dl.sh`) is more robust against a checkout that loses the bit (e.g. on Windows hosts).

3. No `WORKDIR /data` (or similar) for runtime: the script writes its `ard-plus-token` cache and, in the Tatort path, `current-tatort-episode.txt` into the **current working directory**, which is `/app` inside the container. With the documented `docker run -v "$(pwd):/data"` invocation these files land in the ephemeral container layer, so the session token is thrown away after every `--rm` run and each invocation performs a fresh login. Setting `WORKDIR /data` (and documenting it) would persist the token to the host mount.

4. Consider pinning to `alpine:3.22` (minor-version tag) instead of `3.22.0` so patch releases with security fixes are picked up on rebuild.

## Suggested fix

```dockerfile
FROM alpine:3.22

RUN apk add --no-cache bash curl yt-dlp jq util-linux perl

WORKDIR /app
COPY ard-plus-dl.sh graphql-queries.sh ./
RUN chmod +x /app/ard-plus-dl.sh && ln -s /app/ard-plus-dl.sh /usr/bin/download

ENV DOWNLOADS_DIR=/data/downloads
WORKDIR /data
```

Labels: `enhancement`
