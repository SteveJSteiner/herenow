#!/bin/sh
# update-manifest.sh — Regenerate enforcement-manifest on meta and stage new meta pin.
#
# Use this after updating enforcement source files in .now/hooks/ or .now/src/.
# Computes new blob hashes from the working tree, writes an updated
# enforcement-manifest in the meta worktree, commits through the shared
# commit-to-meta helper, and stages the new meta gitlink on now.
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

current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
if [ -z "$current_branch" ]; then
    echo "Error: detached HEAD — run from the now branch." >&2
    exit 1
fi
if [ "$current_branch" != "now" ]; then
    echo "Error: must run from the now branch (current: '$current_branch')." >&2
    exit 1
fi

if ! git rev-parse --verify refs/membrane/root >/dev/null 2>&1; then
    echo "Error: not a membrane repository (refs/membrane/root missing)." >&2
    exit 1
fi

repo_root=$(git rev-parse --show-toplevel)
gitmodules_file="$repo_root/.gitmodules"
if [ ! -f "$gitmodules_file" ]; then
    echo "Error: .gitmodules not found. Run from initialized now after bootstrap." >&2
    exit 1
fi

raw=$(git config --file "$gitmodules_file" --get-regexp '^submodule\.' 2>/dev/null || true)
if [ -z "$raw" ]; then
    echo "Error: no submodules declared in .gitmodules." >&2
    exit 1
fi

meta_name=""
for name in $(printf '%s\n' "$raw" | sed 's/ .*//' | sed 's/^submodule\.//' | sed 's/\.[^.]*$//' | sort -u); do
    role=$(git config --file "$gitmodules_file" "submodule.$name.role" 2>/dev/null || true)
    if [ "$role" = "meta" ]; then
        meta_name=$name
        break
    fi
done

if [ -z "$meta_name" ]; then
    echo "Error: no submodule with role=meta found in .gitmodules." >&2
    exit 1
fi

meta_path=$(git config --file "$gitmodules_file" "submodule.$meta_name.path" 2>/dev/null || true)
[ -n "$meta_path" ] || meta_path=$meta_name
meta_worktree="$repo_root/$meta_path"

if [ ! -d "$meta_worktree" ]; then
    echo "Error: meta worktree not found at '$meta_path'. Run ./bootstrap.sh first." >&2
    exit 1
fi

meta_tip=$(git rev-parse --verify refs/heads/meta 2>/dev/null || true)
if [ -z "$meta_tip" ]; then
    echo "Error: could not resolve refs/heads/meta." >&2
    exit 1
fi

# --- Generate new manifest from working-tree enforcement files ---

manifest_body=""
extra_paths=""
for dir in ".now/hooks" ".now/src"; do
    full="$repo_root/$dir"
    [ -d "$full" ] || continue
    for f in "$full"/*; do
        [ -f "$f" ] || continue
        hash=$(git hash-object "$f")
        rel="${f#${repo_root}/}"
        manifest_body="${manifest_body}${hash} ${rel}
"
    done
done

extra_list_tmp=$(mktemp "${TMPDIR:-/tmp}/extra-manifested-files.XXXXXX")
trap 'rm -f "$extra_list_tmp"' EXIT INT HUP TERM

if git show "$meta_tip:extra-manifested-files" > "$extra_list_tmp" 2>/dev/null; then
    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        line=$(printf '%s' "$raw_line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        case "$line" in
            ''|'#'*) continue ;;
        esac
        case "$line" in
            *[[:space:]]*)
                echo "Error: extra manifested paths must not contain whitespace: $line" >&2
                exit 1
                ;;
        esac
        case "$line" in
            /*)
                echo "Error: unsafe extra manifested path (must be repo-relative): $line" >&2
                exit 1
                ;;
        esac
        case "/$line/" in
            */../*)
                echo "Error: unsafe extra manifested path (must not contain '..'): $line" >&2
                exit 1
                ;;
        esac

        full="$repo_root/$line"
        if [ -L "$full" ]; then
            echo "Error: declared extra manifested file must not be a symlink: $line" >&2
            exit 1
        fi
        if [ ! -f "$full" ]; then
            echo "Error: declared extra manifested file missing: $line" >&2
            exit 1
        fi

        hash=$(git hash-object "$full")
        manifest_body="${manifest_body}${hash} ${line}
"
        extra_paths="${extra_paths}${line}
"
    done < "$extra_list_tmp"
fi

if [ -z "$manifest_body" ]; then
    echo "Error: no enforcement files found in .now/hooks/ or .now/src/." >&2
    exit 1
fi

manifest_body=$(printf '%s' "$manifest_body" | sort)

manifest_path="$meta_worktree/enforcement-manifest"
{
    printf '# Enforcement manifest — updated by update-manifest.sh\n'
    printf '%s\n' "$manifest_body"
} > "$manifest_path"

meta_out=$(sh "$repo_root/.now/src/commit-to-meta.sh" "Update enforcement manifest" "enforcement-manifest")
printf '%s\n' "$meta_out"

# Stage the enforcement files whose hashes were just manifested.
# This makes the operation atomic: manifest + source files land together.
for dir in ".now/hooks" ".now/src"; do
    [ -d "$repo_root/$dir" ] || continue
    git -C "$repo_root" add -- "$dir"
    echo "  Staged $dir"
done

if [ -n "$extra_paths" ]; then
    printf '%s' "$extra_paths" | sort -u | while IFS= read -r path; do
        [ -n "$path" ] || continue
        git -C "$repo_root" add -- "$path"
        echo "  Staged $path"
    done
fi

echo ""
echo "Staged. Commit to record the update:"
echo "  git commit -m \"Update enforcement source\""
