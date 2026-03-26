#!/bin/sh
# graduate-future.sh — Graduate a future branch into its past lineage.
#
# When work on a future branch is ready to be settled, this script advances
# the corresponding past pin to a new commit and removes the future branch
# from the composition. Leaves all changes staged for the operator to commit.
#
# The past branch to advance is read from the future's ancestor-constraint in
# .gitmodules. The new past commit must be a descendant of the current past
# pin; check-past-monotonicity.sh will reject the commit if it is not.
#
# Usage: graduate-future.sh <future-submodule> <new-past-commit>
#   <future-submodule>  Full name of the future submodule (e.g. future/my-spec)
#   <new-past-commit>   Commit the past branch now points to after graduation
#
# After running, review the staged changes and commit with:
#   git commit -m "Graduate <future-submodule> into <past-submodule>"

set -eu

USAGE="Usage: graduate-future.sh <future-submodule> <new-past-commit>"

if [ "$#" -ne 2 ]; then
    echo "$USAGE" >&2
    exit 2
fi

FUTURE_SUB="$1"
NEW_PAST_COMMIT="$2"

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

REPO_ROOT="$(git rev-parse --show-toplevel)"
GITMODULES="$REPO_ROOT/.gitmodules"

if [ ! -f "$GITMODULES" ]; then
    echo "Error: .gitmodules not found. Run from the now branch." >&2
    exit 1
fi

# --- Verify future submodule exists with role=future ---

FUTURE_ROLE=$(git config --file "$GITMODULES" "submodule.$FUTURE_SUB.role" 2>/dev/null || true)
if [ -z "$FUTURE_ROLE" ]; then
    echo "Error: submodule '$FUTURE_SUB' not found in .gitmodules." >&2
    exit 1
fi
if [ "$FUTURE_ROLE" != "future" ]; then
    echo "Error: '$FUTURE_SUB' has role '$FUTURE_ROLE' (must be future)." >&2
    exit 1
fi

# --- Read ancestor-constraint to find the past submodule ---

PAST_SUB=$(git config --file "$GITMODULES" "submodule.$FUTURE_SUB.ancestor-constraint" 2>/dev/null || true)
if [ -z "$PAST_SUB" ]; then
    echo "Error: $FUTURE_SUB has no ancestor-constraint in .gitmodules." >&2
    exit 1
fi

# --- Resolve new past commit ---

NEW_PAST_SHA=$(git rev-parse --verify "$NEW_PAST_COMMIT^{commit}" 2>/dev/null) || {
    echo "Error: commit not found: $NEW_PAST_COMMIT" >&2
    exit 1
}

echo "  Graduating $FUTURE_SUB into $PAST_SUB"

# --- Advance the past pin ---

OLD_PAST_ENTRY=$(git ls-files --stage -- "$PAST_SUB" 2>/dev/null || true)
if [ -n "$OLD_PAST_ENTRY" ]; then
    OLD_PAST_SHA=$(printf '%s' "$OLD_PAST_ENTRY" | awk '{print $2}')
    echo "    $PAST_SUB: $OLD_PAST_SHA -> $NEW_PAST_SHA"
else
    echo "    $PAST_SUB: (no prior pin) -> $NEW_PAST_SHA"
fi
git update-index --add --cacheinfo "160000,$NEW_PAST_SHA,$PAST_SUB"

# --- Remove future gitlink from index ---

git update-index --force-remove -- "$FUTURE_SUB"
echo "    removed gitlink: $FUTURE_SUB"

# --- Remove future entry from .gitmodules ---

git config --file "$GITMODULES" --remove-section "submodule.$FUTURE_SUB"
echo "    removed from .gitmodules: $FUTURE_SUB"

# --- Stage .gitmodules ---

git add "$GITMODULES"

echo ""
echo "Staged. Commit with:"
echo "  git commit -m \"Graduate $FUTURE_SUB into $PAST_SUB\""
