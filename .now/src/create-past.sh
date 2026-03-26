#!/bin/sh
# create-past.sh — Add a past branch to the temporal membrane.
#
# Creates a past/<name> branch and stages the .gitmodules declaration and
# gitlink on the now branch. Leaves changes staged for the operator to commit.
#
# Usage: create-past.sh <name> [<start-point>]
#   <name>         Identifier for the branch (no slashes or dots)
#   <start-point>  Any git commit, branch, or tag (default: HEAD)
#
# After running, review the staged changes and commit with:
#   git commit -m "Add past/<name>"

set -eu

USAGE="Usage: create-past.sh <name> [<start-point>]"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "$USAGE" >&2
    exit 2
fi

NAME="$1"
START="${2:-HEAD}"
BRANCH="past/$NAME"

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
    echo "Recovery: run ./init.sh first." >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
GITMODULES="$REPO_ROOT/.gitmodules"

if [ ! -f "$GITMODULES" ]; then
    echo "Error: .gitmodules not found. Run from the now branch after ./bootstrap.sh." >&2
    exit 1
fi

# --- Validate name ---

case "$NAME" in
    */*|*.*)
        echo "Error: name must not contain / or . (got: $NAME)" >&2
        exit 1
        ;;
esac

# --- Resolve start point ---

START_SHA=$(git rev-parse --verify "$START^{commit}" 2>/dev/null) || {
    echo "Error: start point not found: $START" >&2
    exit 1
}

# --- Check not already declared ---

if git config --file "$GITMODULES" "submodule.$BRANCH.role" >/dev/null 2>&1; then
    echo "Error: $BRANCH is already declared in .gitmodules." >&2
    exit 1
fi

# --- Create or reuse the branch ---

if git rev-parse --verify "refs/heads/$BRANCH" >/dev/null 2>&1; then
    TIP=$(git rev-parse "refs/heads/$BRANCH")
    echo "  $BRANCH already exists at $TIP — reusing."
else
    git branch "$BRANCH" "$START_SHA"
    TIP=$(git rev-parse "refs/heads/$BRANCH")
    echo "  Created $BRANCH at $TIP"
fi

# --- Add to .gitmodules ---

git config --file "$GITMODULES" "submodule.$BRANCH.path" "$BRANCH"
git config --file "$GITMODULES" "submodule.$BRANCH.url" "./"
git config --file "$GITMODULES" "submodule.$BRANCH.role" "past"
echo "  Added [submodule \"$BRANCH\"] to .gitmodules"

# --- Stage gitlink and .gitmodules ---

git update-index --add --cacheinfo "160000,$TIP,$BRANCH"
git add "$GITMODULES"
echo "  Staged gitlink $BRANCH -> $TIP"

echo ""
echo "Staged. Commit with:"
echo "  git commit -m \"Add $BRANCH\""
