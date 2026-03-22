#!/bin/sh
# check-future-grounding.sh — Verify future submodule pins descend from
# their declared past lineage.
#
# Usage: check-future-grounding.sh [path-to-gitmodules]
#   Must be run from the root of a git repository.
#   Reads both future and past pins from the index (candidate composition).
#
# Exit codes:
#   0 — all future pins are grounded (or no futures)
#   1 — one or more future pins are ungrounded
#   2 — usage error
#
# GT8b: Constraint engine v1 — grounded futures.

set -eu

GITMODULES="${1:-.gitmodules}"

if [ ! -f "$GITMODULES" ]; then
    echo "Error: file not found: $GITMODULES" >&2
    exit 2
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not in a git repository" >&2
    exit 2
fi

# --- Helpers ---

err_count=0

get_val() {
    git config --file "$GITMODULES" "submodule.$1.$2" 2>/dev/null || true
}

# --- Parse submodule names ---

raw=$(git config --file "$GITMODULES" --get-regexp '^submodule\.' 2>/dev/null || true)
if [ -z "$raw" ]; then
    exit 0
fi

names=$(printf '%s\n' "$raw" |
    sed 's/ .*//' |
    sed 's/^submodule\.//' |
    sed 's/\.[^.]*$//' |
    sort -u)

if [ -z "$names" ]; then
    exit 0
fi

# --- Check each future-typed submodule ---

for name in $names; do
    role=$(get_val "$name" role)
    if [ "$role" != "future" ]; then
        continue
    fi

    path=$(get_val "$name" path)
    if [ -z "$path" ]; then
        path="$name"
    fi

    ac=$(get_val "$name" ancestor-constraint)
    if [ -z "$ac" ]; then
        echo "FAIL: future submodule '$name': missing ancestor-constraint" >&2
        err_count=$((err_count + 1))
        continue
    fi

    ac_path=$(get_val "$ac" path)
    if [ -z "$ac_path" ]; then
        ac_path="$ac"
    fi

    # Read future pin from index
    future_entry=$(git ls-files --stage -- "$path" 2>/dev/null || true)
    if [ -z "$future_entry" ]; then
        continue
    fi
    future_pin=$(printf '%s' "$future_entry" | awk '{print $2}')

    # Read past pin from index
    past_entry=$(git ls-files --stage -- "$ac_path" 2>/dev/null || true)
    if [ -z "$past_entry" ]; then
        echo "FAIL: future submodule '$name': ancestor-constraint '$ac' has no pin in index" >&2
        err_count=$((err_count + 1))
        continue
    fi
    past_pin=$(printf '%s' "$past_entry" | awk '{print $2}')

    # Find fork point
    fork_point=$(git merge-base "$future_pin" "$past_pin" 2>/dev/null) || {
        echo "FAIL: future submodule '$name': no common ancestor with past '$ac'" >&2
        echo "  future pin: $future_pin" >&2
        echo "  past pin:   $past_pin" >&2
        err_count=$((err_count + 1))
        continue
    }

    # Fork point must not be a root commit (trivial shared history)
    if ! git rev-parse --verify "${fork_point}^" >/dev/null 2>&1; then
        echo "FAIL: future submodule '$name': fork point with past '$ac' is a root commit (trivial shared history)" >&2
        echo "  future pin:  $future_pin" >&2
        echo "  past pin:    $past_pin" >&2
        echo "  fork point:  $fork_point" >&2
        err_count=$((err_count + 1))
        continue
    fi
done

if [ "$err_count" -gt 0 ]; then
    echo "$err_count grounding violation(s) found." >&2
    exit 1
fi

exit 0
