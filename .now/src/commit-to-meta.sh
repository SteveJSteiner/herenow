#!/bin/sh
# commit-to-meta.sh — canonical helper for meta commits + now gitlink staging.
#
# Usage:
#   sh .now/src/commit-to-meta.sh <commit-message> <path> [<path>...]

set -eu

if [ "$#" -lt 2 ]; then
    echo "Usage: commit-to-meta.sh <commit-message> <path> [<path>...]" >&2
    exit 1
fi

commit_message=$1
shift

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not inside a git repository." >&2
    exit 1
fi

current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
if [ "$current_branch" != "now" ]; then
    echo "Error: commit-to-meta.sh must run from now (current: ${current_branch:-detached HEAD})." >&2
    exit 1
fi

if ! git rev-parse --verify refs/membrane/root >/dev/null 2>&1; then
    echo "Error: not a membrane repository (refs/membrane/root missing)." >&2
    exit 1
fi

repo_root=$(git rev-parse --show-toplevel)
git_dir=$(git rev-parse --git-dir)
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

# Guard: only declared paths may be dirty in meta worktree.
unexpected_dirty=""
while IFS= read -r dirty_path; do
    [ -z "$dirty_path" ] && continue
    declared=false
    for declared_path in "$@"; do
        if [ "$dirty_path" = "$declared_path" ]; then
            declared=true
            break
        fi
    done
    if [ "$declared" = false ]; then
        unexpected_dirty="${unexpected_dirty}${dirty_path}\n"
    fi
done <<EOF_DIRTY
$(
    {
        git -C "$meta_worktree" diff --name-only
        git -C "$meta_worktree" diff --cached --name-only
        git -C "$meta_worktree" ls-files --others --exclude-standard
    } | sort -u
)
EOF_DIRTY

if [ -n "$unexpected_dirty" ]; then
    echo "Error: meta has dirty paths beyond declared commit scope:" >&2
    printf '%b' "$unexpected_dirty" >&2
    exit 1
fi

meta_tip=$(git rev-parse refs/heads/meta 2>/dev/null || true)
if [ -z "$meta_tip" ]; then
    echo "Error: refs/heads/meta not found." >&2
    exit 1
fi

temp_index="$git_dir/index.commit-to-meta.tmp"
trap 'rm -f "$temp_index"' EXIT
GIT_INDEX_FILE="$temp_index" git read-tree "${meta_tip}^{tree}"

for rel_path in "$@"; do
    src="$meta_worktree/$rel_path"
    if [ -f "$src" ]; then
        mode=100644
        if [ -x "$src" ]; then
            mode=100755
        fi
        blob=$(git hash-object -w "$src")
        GIT_INDEX_FILE="$temp_index" git update-index --add --cacheinfo "$mode,$blob,$rel_path"
    else
        GIT_INDEX_FILE="$temp_index" git update-index --remove -- "$rel_path" >/dev/null 2>&1 || true
    fi
done

old_tree=$(git rev-parse "${meta_tip}^{tree}")
new_tree=$(GIT_INDEX_FILE="$temp_index" git write-tree)

if [ "$old_tree" = "$new_tree" ]; then
    echo "No changes detected for declared meta paths; skipping meta commit." >&2
    git update-index --add --cacheinfo "160000,$meta_tip,$meta_path"
    printf '%s\n' "$meta_tip"
    exit 0
fi

meta_sha=$(git commit-tree "$new_tree" -p "$meta_tip" -m "$commit_message")
git update-ref refs/heads/meta "$meta_sha"

# Stage gitlink update on now.
git update-index --add --cacheinfo "160000,$meta_sha,$meta_path"
echo "Committed declared meta paths and staged gitlink update." >&2

printf '%s\n' "$meta_sha"
