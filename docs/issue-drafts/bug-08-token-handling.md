# Bug: fragile and insecure session-token handling (`ard-plus-token`)

## Description

Several related problems around the cached session token:

1. **CWD-relative path.** `FILE=ard-plus-token` is resolved relative to the current directory. Running the script from a different directory silently triggers a fresh login instead of reusing the cached session; in batch mode the token lands next to wherever the user happened to be, not next to the links file or in a state directory.

2. **World-readable secret.** The token is written with default permissions (`echo $token > $FILE`), so on multi-user systems other local users can read a valid ARD-Plus session token.

3. **Fragile validation.** The login result is validated by base64-decoding the first JWT segment:

   ```bash
   tokenType=$(echo $token | cut -f1 -d "." | base64 -d | jq -r '.typ')
   ```

   JWT headers use **base64url** encoding without padding; `base64 -d` fails on any header whose length is not a multiple of 4 or that contains `-`/`_` characters. Coincidentally the current header decodes, but any change on the server side breaks login validation with a confusing "Login not possible!" error. The unquoted `$token` (shellcheck SC2086) also breaks if the grep ever matches more than one line.

4. **Expired-token fallback can use a stale file.** In `ensure_token`, when the cached token fails the auth probe, `login` is called and then the file is re-read — but if `login` fails *before* the `exit 1` path in a way that leaves the old file in place, the stale token is silently reused. Deleting the file before re-login (or writing atomically) would make this deterministic.

5. The auth probe uses a **hard-coded content ID** (`movieId="a0S010000007GcX"`); if that item is ever removed from the catalog, token validation breaks for everyone.

## Suggested fix

- Store the token in a fixed location, e.g. `${XDG_STATE_HOME:-$HOME/.local/state}/ard-plus-dl/token` or next to the script, and create it with `umask 077` / `install -m 600`.
- Validate the token with a tolerant base64url decode (`tr '_-' '/+'` plus padding) or simply by probing an authenticated endpoint and checking for HTTP 200.
- Remove the cached file before attempting a re-login.

Labels: `bug`, `security`
