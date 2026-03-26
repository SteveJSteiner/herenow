#!/bin/sh
# update-manifest.sh — Regenerate enforcement-manifest on meta and stage new meta pin.
#
# Use this after updating enforcement source files in .now/hooks/ or .now/src/.
# Computes new blob hashes from the working tree, commits an updated
# enforcement-manifest to the meta branch (without checking it out), and stages
# the new meta gitlink on now.
#
# After running, commit:
#   git commit -m "Update enforcement source"
#
# The script stages both the updated meta gitlink and the enforcement files
# it manifested, so no manual git add is needed.
#
# Usage: update-manifest.sh
#   Must be run from the now branch after bootstrap.

set -eu

# --- Preconditions ---

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not inside a git repository." >&2
    exit 1
fi

_current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
if [ -z "$_current_branch" ]; then
    echo "Error: detached HEAD — run from the now branch." >&2
    exit 1
fi
if [ "$_current_branch" != "now" ]; then
    echo "Error: must run from the now branch (current: '$_current_branch')." >&2
    exit 1
fi

if ! git rev-parse --verify refs/membrane/root >/dev/null 2>&1; then
    echo "Error: not a membrane repository (refs/membrane/root missing)." >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
GIT_DIR="$(git rev-parse --git-dir)"
GITMODULES="$REPO_ROOT/.gitmodules"

if [ ! -f "$GITMODULES" ]; then
    echo "Error: .gitmodules not found. Run from the now branch after ./bootstrap.sh." >&2
    exit 1
fi

# --- Find meta submodule name ---

_raw=$(git config --file "$GITMODULES" --get-regexp '^submodule\.' 2>/dev/null || true)
if [ -z "$_raw" ]; then
    echo "Error: no submodules in .gitmodules." >&2
    exit 1
fi

_names=$(printf '%s\n' "$_raw" \
    | sed 's/ .*//' \
    | sed 's/^submodule\.//' \
    | sed 's/\.[^.]*$//' \
    | sort -u)

_meta_name=""
for _name in $_names; do
    _role=$(git config --file "$GITMODULES" "submodule.$_name.role" 2>/dev/null || true)
    if [ "$_role" = "meta" ]; then
        _meta_name="$_name"
        break
    fi
done

if [ -z "$_meta_name" ]; then
    echo "Error: no meta submodule found in .gitmodules." >&2
    exit 1
fi

# Read the submodule path (rule 5 of validate-gitmodules.sh enforces path==name,
# but read it explicitly to stay consistent with check-meta-consistency.sh).
_meta_path=$(git config --file "$GITMODULES" "submodule.$_meta_name.path" 2>/dev/null || true)
if [ -z "$_meta_path" ]; then
    _meta_path="$_meta_name"
fi

# --- Get current meta tip ---

_meta_tip=$(git rev-parse "refs/heads/meta" 2>/dev/null) || {
    echo "Error: refs/heads/meta not found." >&2
    exit 1
}

# --- Generate new manifest from working-tree enforcement files ---

TEMP_INDEX="$GIT_DIR/index.update-manifest.tmp"
trap 'rm -f "$TEMP_INDEX"' EXIT

# Collect enforcement file hashes from working tree.
# format: "<hash> <relative-path>" — same format as check-meta-consistency.sh expects.
_manifest_body=""
for _dir in ".now/hooks" ".now/src"; do
    _full="$REPO_ROOT/$_dir"
    [ -d "$_full" ] || continue
    for _f in "$_full"/*; do
        [ -f "$_f" ] || continue
        _hash=$(git hash-object "$_f")
        _rel="${_f#${REPO_ROOT}/}"
        _manifest_body="${_manifest_body}${_hash} ${_rel}
"
    done
done

if [ -z "$_manifest_body" ]; then
    echo "Error: no enforcement files found in .now/hooks/ or .now/src/." >&2
    exit 1
fi

# Sort for stable output across runs.
_manifest_body=$(printf '%s' "$_manifest_body" | sort)

_manifest_blob=$(
    { printf '# Enforcement manifest — updated by update-manifest.sh\n'
      printf '%s\n' "$_manifest_body"
    } | git hash-object -w --stdin
)

# --- Commit updated manifest to meta (no checkout required) ---

GIT_INDEX_FILE="$TEMP_INDEX" git read-tree "${_meta_tip}^{tree}"
GIT_INDEX_FILE="$TEMP_INDEX" git update-index \
    --add --cacheinfo "100644,$_manifest_blob,enforcement-manifest"
_tree=$(GIT_INDEX_FILE="$TEMP_INDEX" git write-tree)
_commit=$(git commit-tree "$_tree" -p "$_meta_tip" \
    -m "Update enforcement manifest")
git update-ref refs/heads/meta "$_commit"

echo "  meta -> $_commit"

# --- Stage new meta gitlink on now ---

git update-index --add --cacheinfo "160000,$_commit,$_meta_path"
echo "  Staged gitlink $_meta_path -> $_commit"

# Stage the enforcement files whose hashes were just manifested.
# This makes the operation atomic: manifest + source files land together.
for _dir in ".now/hooks" ".now/src"; do
    [ -d "$REPO_ROOT/$_dir" ] || continue
    git -C "$REPO_ROOT" add -- "$_dir"
    echo "  Staged $_dir"
done

echo ""
echo "Staged. Commit to record the update:"
echo "  git commit -m \"Update enforcement source\""
