#!/bin/sh
# provision-worktrees.sh — Create worktrees for membrane branch roles.
#
# Reads .gitmodules to discover declared submodule branches, then creates
# worktrees at wt/<name>/ for each role branch not already checked out.
#
# Idempotent: re-running is safe. Existing worktrees are skipped.
# Optional: enforcement works without worktrees. This is purely ergonomic.
#
# Exit codes:
#   0 — success (all requested worktrees exist or were created)
#   1 — failure (one or more worktrees could not be created)
#   2 — precondition failure (not a membrane repo)

set -eu

# --- Preconditions ---

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not inside a git repository." >&2
    exit 2
fi

if ! git rev-parse --verify refs/membrane/root >/dev/null 2>&1; then
    echo "Error: not initialized (refs/membrane/root missing)." >&2
    echo "Recovery: run init.sh first." >&2
    exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
WT_DIR="$REPO_ROOT/wt"
CURRENT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo "")"

# --- Discover branches ---

_gitmodules_file=""
_tmp_file=""

# Prefer .gitmodules from working tree; fall back to now branch tree
if [ -f "$REPO_ROOT/.gitmodules" ]; then
    _gitmodules_file="$REPO_ROOT/.gitmodules"
elif git show refs/heads/now:.gitmodules >/dev/null 2>&1; then
    _tmp_file=$(mktemp)
    git show refs/heads/now:.gitmodules > "$_tmp_file"
    _gitmodules_file="$_tmp_file"
fi

cleanup() {
    if [ -n "$_tmp_file" ]; then
        rm -f "$_tmp_file"
    fi
}
trap cleanup EXIT

# Extract submodule names (each submodule name = branch name by convention)
_branches="now"
if [ -n "$_gitmodules_file" ]; then
    while IFS= read -r _line; do
        case "$_line" in
            *'[submodule "'*)
                _name="${_line#*\"}"
                _name="${_name%\"*}"
                # Deduplicate
                case " $_branches " in
                    *" $_name "*) ;;
                    *) _branches="$_branches $_name" ;;
                esac
                ;;
        esac
    done < "$_gitmodules_file"
fi

# --- Provision worktrees ---

_created=0
_skipped=0
_missing=0
_errors=0

for _branch in $_branches; do
    # Current checkout already has a worktree (the repo root)
    if [ "$_branch" = "$CURRENT_BRANCH" ]; then
        _skipped=$((_skipped + 1))
        continue
    fi

    # Branch must exist
    if ! git rev-parse --verify "refs/heads/$_branch" >/dev/null 2>&1; then
        echo "  skip: $_branch (branch not found)"
        _missing=$((_missing + 1))
        continue
    fi

    _wt_path="$WT_DIR/$_branch"

    # Already has a worktree somewhere (could be at a different path)
    if git worktree list --porcelain 2>/dev/null | grep -q "^branch refs/heads/$_branch$"; then
        _skipped=$((_skipped + 1))
        continue
    fi

    # Path exists but isn't a worktree — don't clobber
    if [ -e "$_wt_path" ]; then
        echo "  skip: wt/$_branch (path exists, not a worktree)"
        _skipped=$((_skipped + 1))
        continue
    fi

    # Create
    mkdir -p "$WT_DIR"
    if git worktree add "$_wt_path" "$_branch" >/dev/null 2>&1; then
        echo "  created: wt/$_branch -> $_branch"
        _created=$((_created + 1))
    else
        echo "  error: wt/$_branch (git worktree add failed)" >&2
        _errors=$((_errors + 1))
    fi
done

# --- Summary ---

echo ""
echo "Provisioned: $_created created, $_skipped skipped, $_missing not found."

if [ "$_created" -gt 0 ]; then
    _has_wt_ignore=false
    if [ -f "$REPO_ROOT/.gitignore" ]; then
        if grep -q "^wt/" "$REPO_ROOT/.gitignore" 2>/dev/null || \
           grep -q "^wt$" "$REPO_ROOT/.gitignore" 2>/dev/null; then
            _has_wt_ignore=true
        fi
    fi
    if [ "$_has_wt_ignore" = false ]; then
        echo ""
        echo "Hint: add 'wt/' to .gitignore to hide worktree directories from git status."
    fi
fi

if [ "$_errors" -gt 0 ]; then
    exit 1
fi
