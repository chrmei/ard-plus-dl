#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0

pass() {
    PASS=$((PASS + 1))
    printf '  ok  %s\n' "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf ' FAIL %s\n' "$1" >&2
    [[ $# -gt 1 ]] && printf '       %s\n' "$2" >&2
}

assert_equals() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "expected '$expected', got '$actual'"
    fi
}

assert_success() {
    local name="$1"
    shift
    if "$@"; then
        pass "$name"
    else
        fail "$name" "expected success"
    fi
}

assert_failure() {
    local name="$1"
    shift
    if "$@"; then
        fail "$name" "expected failure"
    else
        pass "$name"
    fi
}

assert_exit() {
    local name="$1" expected="$2"
    shift 2
    set +e
    "$@" >/dev/null 2>&1
    local status=$?
    set -e
    if [[ $status -eq $expected ]]; then
        pass "$name"
    else
        fail "$name" "expected exit $expected, got $status"
    fi
}

assert_output_contains() {
    local name="$1" needle="$2"
    shift 2
    local output
    set +e
    output="$("$@" 2>&1)"
    local status=$?
    set -e
    if [[ $status -eq 0 || $status -eq 1 ]] && [[ "$output" == *"$needle"* ]]; then
        pass "$name"
    else
        fail "$name" "output did not contain '$needle'"
    fi
}

# shellcheck source=../ard-plus-dl.sh
source "$ROOT_DIR/ard-plus-dl.sh"

test_normalize_url() {
    printf '\n[normalize_url]\n'
    assert_equals 'strips trailing slash' \
        'https://www.ardplus.de/details/foo' \
        "$(normalize_url 'https://www.ardplus.de/details/foo/')"
    assert_equals 'strips comments' \
        'https://www.ardplus.de/details/foo' \
        "$(normalize_url 'https://www.ardplus.de/details/foo # note')"
    assert_equals 'trims whitespace' \
        'https://www.ardplus.de/details/foo' \
        "$(normalize_url '  https://www.ardplus.de/details/foo  ')"
}

test_graphql_response_ok() {
    printf '\n[graphql_response_ok]\n'
    assert_success 'accepts valid response' \
        graphql_response_ok "$FIXTURES_DIR/graphql-ok.json"
    assert_failure 'rejects graphql error' \
        graphql_response_ok "$FIXTURES_DIR/graphql-error.json"
    assert_failure 'rejects missing file' \
        graphql_response_ok "$FIXTURES_DIR/does-not-exist.json"
}

test_download_paths() {
    printf '\n[download paths]\n'
    local tmp
    tmp=$(mktemp -d)
    downloads_dir="$tmp/downloads"
    mkdir -p "$downloads_dir"

    assert_equals 'resolve_download_path' \
        "$downloads_dir/Show/Season 01/Episode" \
        "$(resolve_download_path 'Show/Season 01/Episode')"
    assert_equals 'output_mp4_path' \
        "$downloads_dir/Movie (2024)/Movie.mp4" \
        "$(output_mp4_path 'Movie (2024)/Movie')"
}

test_skip_logic() {
    printf '\n[skip logic]\n'
    local tmp
    tmp=$(mktemp -d)
    downloads_dir="$tmp/downloads"
    skip_existing_files=1
    batch_mode=0
    mkdir -p "$downloads_dir/Complete Show"

    local output_path
    output_path="$(output_mp4_path 'Complete Show/movie')"
    printf 'video' >"$output_path"

    assert_success 'detects complete file' is_complete_file 'Complete Show/movie'
    assert_success 'skips existing complete file' skip_if_exists 'Complete Show/movie'

    mkdir -p "$downloads_dir/Partial Show"
    output_path="$(output_mp4_path 'Partial Show/movie')"
    printf 'partial' >"${output_path}.part-Frag1"
    touch "${output_path}.part-Frag1"

    assert_failure 'detects incomplete artifacts' is_complete_file 'Partial Show/movie'
    assert_failure 'does not skip incomplete download' skip_if_exists 'Partial Show/movie'

    skip_existing_files=0
    assert_failure 'force redownload ignores complete file' skip_if_exists 'Complete Show/movie'
}

test_episode_json_parsing() {
    printf '\n[episode json parsing]\n'
    local episodes='[{"id":"1","episodeNo":1,"title":"Say \"Hi\" Ep","videoUrl":"https://example.com/v"}]'
    local episode_line title

    episode_line=$(echo "$episodes" | jq -c '.[]' | head -n 1)
    title=$(echo "$episode_line" | jq -r '.title')
    assert_equals 'preserves quotes in episode title' 'Say "Hi" Ep' "$title"
}

test_cli_validation() {
    printf '\n[cli validation]\n'
    local script="$ROOT_DIR/ard-plus-dl.sh"

    assert_exit 'missing credentials' 1 bash "$script"
    assert_output_contains 'missing url' 'URL or --links-file required' \
        bash "$script" '' user pass
    assert_output_contains 'links-file requires argument' '--links-file requires a file argument' \
        bash "$script" --links-file
    assert_output_contains 'links file not found' 'Links file missing or not found' \
        bash "$script" --links-file "$FIXTURES_DIR/missing.txt" user pass
}

main() {
    printf 'Running ard-plus-dl tests...\n'
    test_normalize_url
    test_graphql_response_ok
    test_download_paths
    test_skip_logic
    test_episode_json_parsing
    test_cli_validation

    printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
    [[ $FAIL -eq 0 ]]
}

main "$@"
