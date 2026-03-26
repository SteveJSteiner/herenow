#!/bin/sh
# create-future.sh — Add a future branch to the temporal membrane.
#
# Creates a future/<name> branch grounded in an existing past submodule, and
# stages the .gitmodules declaration and gitlink on the now branch. Leaves
# changes staged for the operator to commit.
#
# Usage: create-future.sh <name> <past-submodule> [<start-point>]
#   <name>            Identifier for the branch (no slashes or dots)
#   <past-submodule>  Full name of the past submodule (e.g. past/my-work)
#   <start-point>     Commit to start from (default: tip of past-submodule)
#
# The future branch must share non-trivial ancestry with the named past branch
# (i.e. a common ancestor that is not the membrane root). Branching from the
# past tip (the default) satisfies this automatically.
#
# After running, review the staged changes and commit with:
#   git commit -m "Add future/<name>"

set -eu

USAGE="Usage: create-future.sh <name> <past-submodule> [<start-point>]"

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "$USAGE" >&2
    exit 2
fi

NAME="$1"
PAST_SUB="$2"
BRANCH="future/$NAME"

# --- Preconditions ---

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not inside a git repository." >&2
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

# --- Verify past submodule exists and has role=past ---

PAST_ROLE=$(git config --file "$GITMODULES" "submodule.$PAST_SUB.role" 2>/dev/null || true)
if [ -z "$PAST_ROLE" ]; then
    echo "Error: submodule '$PAST_SUB' not found in .gitmodules." >&2
    echo "Hint: create a past branch first with create-past.sh." >&2
    exit 1
fi
if [ "$PAST_ROLE" != "past" ]; then
    echo "Error: '$PAST_SUB' has role '$PAST_ROLE' (must be past)." >&2
    exit 1
fi

# --- Verify the past branch exists ---

if ! git rev-parse --verify "refs/heads/$PAST_SUB" >/dev/null 2>&1; then
    echo "Error: branch $PAST_SUB not found." >&2
    exit 1
fi

# --- Resolve start point ---

if [ "$#" -eq 3 ]; then
    START_SHA=$(git rev-parse --verify "$3^{commit}" 2>/dev/null) || {
        echo "Error: start point not found: $3" >&2
        exit 1
    }
else
    # Default: branch from the tip of the past branch.
    START_SHA=$(git rev-parse "refs/heads/$PAST_SUB")
fi

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
git config --file "$GITMODULES" "submodule.$BRANCH.role" "future"
git config --file "$GITMODULES" "submodule.$BRANCH.ancestor-constraint" "$PAST_SUB"
echo "  Added [submodule \"$BRANCH\"] with ancestor-constraint = $PAST_SUB"

# --- Stage gitlink and .gitmodules ---

git update-index --add --cacheinfo "160000,$TIP,$BRANCH"
git add "$GITMODULES"
echo "  Staged gitlink $BRANCH -> $TIP"

echo ""
echo "Staged. Commit with:"
echo "  git commit -m \"Add $BRANCH\""
