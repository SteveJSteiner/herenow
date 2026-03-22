#!/bin/sh
# check-meta-consistency.sh — Verify enforcement machinery matches meta declaration.
#
# The meta branch carries an enforcement-manifest listing each enforcement
# file and its expected git blob hash. This checker reads the manifest from
# the meta submodule pin (via git objects — no submodule init required),
# computes git hash-object of each active working-tree file, and reports
# per-file mismatches.
#
# Usage: check-meta-consistency.sh [path-to-gitmodules]
#   Must be run from the root of a git repository.
#
# Exit codes:
#   0 — consistent (or no meta submodule declared)
#   1 — one or more inconsistencies detected
#   2 — usage error
#
# GT11: Meta self-consistency mechanism.

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

REPO_ROOT="$(git rev-parse --show-toplevel)"

# --- Helpers ---

get_val() {
    git config --file "$GITMODULES" "submodule.$1.$2" 2>/dev/null || true
}

# --- Find meta submodule ---

raw=$(git config --file "$GITMODULES" --get-regexp '^submodule\.' 2>/dev/null || true)
if [ -z "$raw" ]; then
    # No submodule entries — nothing to check.
    exit 0
fi

names=$(printf '%s\n' "$raw" |
    sed 's/ .*//' |
    sed 's/^submodule\.//' |
    sed 's/\.[^.]*$//' |
    sort -u)

meta_name=""
for name in $names; do
    role=$(get_val "$name" role)
    if [ "$role" = "meta" ]; then
        meta_name="$name"
        break
    fi
done

if [ -z "$meta_name" ]; then
    # No meta submodule declared — nothing to check.
    exit 0
fi

meta_path=$(get_val "$meta_name" path)
if [ -z "$meta_path" ]; then
    meta_path="$meta_name"
fi

# --- Get meta pin SHA from the index ---
# Uses git ls-files --stage to read the gitlink entry. This works in both
# pre-commit (candidate state) and post-commit (committed state = index).
# No submodule init or checkout required.

meta_entry=$(git ls-files --stage -- "$meta_path" 2>/dev/null || true)
if [ -z "$meta_entry" ]; then
    # Meta declared in .gitmodules but no gitlink in index — not yet pinned.
    # This is not an error for the consistency check; there is nothing to
    # compare against.
    exit 0
fi

meta_pin=$(printf '%s' "$meta_entry" | awk '{print $2}')

if [ -z "$meta_pin" ]; then
    echo "meta-consistency: could not read meta pin SHA from index" >&2
    exit 1
fi

# Verify the pin points to a commit object we can read.
if ! git cat-file -t "$meta_pin" >/dev/null 2>&1; then
    echo "meta-consistency: meta pin $meta_pin not found in object store" >&2
    exit 1
fi

# --- Read enforcement manifest from meta pin ---

manifest=$(git show "$meta_pin:enforcement-manifest" 2>/dev/null) || {
    echo "meta-consistency: no enforcement-manifest at meta pin $meta_pin" >&2
    exit 1
}

# --- Compare each declared file ---

err_count=0
checked=0

while IFS= read -r line; do
    # Skip comments and empty lines.
    case "$line" in
        '#'*|'') continue ;;
    esac

    expected_hash=$(printf '%s' "$line" | awk '{print $1}')
    file_path=$(printf '%s' "$line" | awk '{print $2}')

    if [ -z "$expected_hash" ] || [ -z "$file_path" ]; then
        continue
    fi

    checked=$((checked + 1))
    full_path="$REPO_ROOT/$file_path"

    if [ ! -f "$full_path" ]; then
        echo "FAIL [meta-consistency]: $file_path — file missing (expected blob $expected_hash)" >&2
        err_count=$((err_count + 1))
        continue
    fi

    actual_hash=$(git hash-object "$full_path")

    if [ "$actual_hash" != "$expected_hash" ]; then
        echo "FAIL [meta-consistency]: $file_path — blob mismatch" >&2
        echo "  expected: $expected_hash" >&2
        echo "  actual:   $actual_hash" >&2
        err_count=$((err_count + 1))
    fi
done <<EOF
$manifest
EOF

if [ "$checked" -eq 0 ]; then
    echo "meta-consistency: enforcement-manifest is empty (no files declared)" >&2
    exit 1
fi

if [ "$err_count" -gt 0 ]; then
    echo "$err_count meta-consistency violation(s) found." >&2
    exit 1
fi

exit 0
