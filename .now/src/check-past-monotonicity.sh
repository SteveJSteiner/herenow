#!/bin/sh
# check-past-monotonicity.sh — Verify past submodule pins advance monotonically.
#
# Usage: check-past-monotonicity.sh [path-to-gitmodules]
#   Must be run from the root of a git repository.
#   Compares HEAD gitlinks vs index gitlinks for past-typed submodules.
#
# Exit codes:
#   0 — all past pins advance monotonically (or no changes)
#   1 — one or more past pins violate monotonicity
#   2 — usage error
#
# GT8a: Constraint engine v1 — past monotonicity.

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

# --- Check each past-typed submodule ---

for name in $names; do
    role=$(get_val "$name" role)
    if [ "$role" != "past" ]; then
        continue
    fi

    path=$(get_val "$name" path)
    if [ -z "$path" ]; then
        path="$name"
    fi

    # Old pin: gitlink SHA in HEAD
    old_pin=""
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
        old_entry=$(git ls-tree HEAD -- "$path" 2>/dev/null || true)
        if [ -n "$old_entry" ]; then
            old_pin=$(printf '%s' "$old_entry" | awk '{print $3}')
        fi
    fi

    # New pin: gitlink SHA in index
    new_entry=$(git ls-files --stage -- "$path" 2>/dev/null || true)
    if [ -z "$new_entry" ]; then
        continue
    fi
    new_pin=$(printf '%s' "$new_entry" | awk '{print $2}')

    # Newly added: no old pin
    if [ -z "$old_pin" ]; then
        continue
    fi

    # Unchanged
    if [ "$old_pin" = "$new_pin" ]; then
        continue
    fi

    # Monotonicity: new must descend from old
    if ! git merge-base --is-ancestor "$old_pin" "$new_pin" 2>/dev/null; then
        echo "FAIL: past submodule '$name': pin is not a descendant of current pin" >&2
        echo "  old pin (HEAD): $old_pin" >&2
        echo "  new pin (index): $new_pin" >&2
        err_count=$((err_count + 1))
    fi
done

if [ "$err_count" -gt 0 ]; then
    echo "$err_count monotonicity violation(s) found." >&2
    exit 1
fi

exit 0
