#!/bin/sh
# validate-gitmodules.sh — Parse .gitmodules role declarations and validate
# the six static schema rules from decisions.md §3.2.
#
# Usage: validate-gitmodules.sh [path-to-gitmodules]
#   Defaults to .gitmodules in the current directory.
#
# Exit codes:
#   0 — valid (all rules pass)
#   1 — invalid (one or more violations)
#   2 — usage error (file not found, etc.)
#
# GT7: Role parser and static config validation.

set -eu

GITMODULES="${1:-.gitmodules}"

if [ ! -f "$GITMODULES" ]; then
    echo "Error: file not found: $GITMODULES" >&2
    exit 2
fi

# --- Helpers ---

err_count=0

fail() {
    echo "FAIL [rule-$1]: $2" >&2
    err_count=$((err_count + 1))
}

get_val() {
    git config --file "$GITMODULES" "submodule.$1.$2" 2>/dev/null || true
}

has_key() {
    git config --file "$GITMODULES" "submodule.$1.$2" >/dev/null 2>&1
}

# --- Parse submodule names ---

# git config output lines: "submodule.<name>.<key> <value>"
# Strip value, prefix, and last .key segment to extract unique names.
raw=$(git config --file "$GITMODULES" --get-regexp '^submodule\.' 2>/dev/null || true)

if [ -z "$raw" ]; then
    # No submodule entries — valid (empty or non-submodule content).
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

# --- Collect roles for cross-referencing (rule 2) ---

role_map=""
for name in $names; do
    r=$(get_val "$name" role)
    role_map="$role_map $name:$r"
done

get_role() {
    for _pair in $role_map; do
        _n="${_pair%%:*}"
        _r="${_pair#*:}"
        if [ "$_n" = "$1" ]; then
            printf '%s' "$_r"
            return
        fi
    done
}

# --- Rule 6: No duplicate paths ---

all_paths=""
for name in $names; do
    p=$(get_val "$name" path)
    if [ -n "$p" ]; then
        all_paths="${all_paths}${p}
"
    fi
done

dupes=$(printf '%s' "$all_paths" | sed '/^$/d' | sort | uniq -d)
if [ -n "$dupes" ]; then
    printf '%s\n' "$dupes" | while IFS= read -r d; do
        fail 6 "duplicate path: $d"
    done
fi

# --- Per-submodule rules ---

for name in $names; do
    path=$(get_val "$name" path)
    url=$(get_val "$name" url)
    role=$(get_val "$name" role)

    # Rule 1: role must exist and be one of {past, future, meta}.
    if [ -z "$role" ]; then
        fail 1 "submodule '$name': missing role key"
    elif [ "$role" != "past" ] && [ "$role" != "future" ] && [ "$role" != "meta" ]; then
        fail 1 "submodule '$name': invalid role '$role' (must be past, future, or meta)"
    fi

    # Rule 4: url must be ./
    if [ -z "$url" ]; then
        fail 4 "submodule '$name': missing url key"
    elif [ "$url" != "./" ]; then
        fail 4 "submodule '$name': url is '$url' (must be ./)"
    fi

    # Rule 5: path must equal submodule name.
    if [ -z "$path" ]; then
        fail 5 "submodule '$name': missing path key"
    elif [ "$path" != "$name" ]; then
        fail 5 "submodule '$name': path is '$path' (must equal submodule name)"
    fi

    # Rules 2 & 3: ancestor-constraint depends on role.
    if [ "$role" = "future" ]; then
        # Rule 2: future must have ancestor-constraint naming a past submodule.
        if ! has_key "$name" ancestor-constraint; then
            fail 2 "submodule '$name' (future): missing ancestor-constraint"
        else
            ac=$(get_val "$name" ancestor-constraint)
            ac_role=$(get_role "$ac")
            if [ -z "$ac_role" ]; then
                fail 2 "submodule '$name' (future): ancestor-constraint names '$ac' which does not exist"
            elif [ "$ac_role" != "past" ]; then
                fail 2 "submodule '$name' (future): ancestor-constraint names '$ac' which has role '$ac_role' (must be past)"
            fi
        fi
    elif [ "$role" = "past" ] || [ "$role" = "meta" ]; then
        # Rule 3: past and meta must not carry ancestor-constraint.
        if has_key "$name" ancestor-constraint; then
            fail 3 "submodule '$name' ($role): must not have ancestor-constraint"
        fi
    fi
done

# --- Result ---

if [ "$err_count" -gt 0 ]; then
    echo "$err_count violation(s) found." >&2
    exit 1
fi

exit 0
