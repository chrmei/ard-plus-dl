# Bug: `--links-file` without a value hangs the script in an infinite loop

## Description

The argument parser calls `shift 2` when it sees `--links-file`. If `--links-file` is the **last** argument (the file name was forgotten), only one positional parameter is left, so `shift 2` fails and shifts nothing. `$1` stays `--links-file` forever and the `while [[ $# -gt 0 ]]` loop spins at 100 % CPU without ever exiting.

Affected code (`ard-plus-dl.sh`):

```bash
--links-file)
    batch_mode=1
    links_file=$2
    shift 2
    ;;
```

## Reproduction

```bash
./ard-plus-dl.sh --links-file
# never returns, one CPU core pinned
```

(Verified: a minimal reproduction of the parser loop had to be killed by `timeout`.)

## Suggested fix

Validate that a value is present before shifting, e.g.:

```bash
--links-file)
    if [[ -z "$2" ]]; then
        echo "Error: --links-file requires a file argument" >&2
        exit 1
    fi
    batch_mode=1
    links_file=$2
    shift 2
    ;;
```

Labels: `bug`
