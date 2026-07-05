# Improvement: avoid passing credentials as command-line arguments

## Description

Username and password are taken as positional CLI arguments:

```bash
./ard-plus-dl.sh <url> <username> <password>
```

Command-line arguments are visible to **every process on the machine** via `ps`/`/proc/<pid>/cmdline` for the lifetime of the script (which can be hours in batch mode), and they end up in the shell history file in plain text. The README and Docker examples encourage this pattern.

## Suggested fix

Support (in order of preference):

1. Environment variables (`ARD_PLUS_USER` / `ARD_PLUS_PASSWORD`) — also the natural fit for the Docker use case (`docker run -e ...` or `--env-file`).
2. An optional credentials file (e.g. `~/.config/ard-plus-dl/credentials` with mode 600), or `read -rs` prompting when credentials are absent and the session token is invalid.
3. Keep the positional arguments for backward compatibility, but document the risk in the README.

Note that once a valid `ard-plus-token` exists, the credentials are not needed at all — the argument check (`Credentials missing!`) could be relaxed to allow token-only runs.

Labels: `enhancement`, `security`
