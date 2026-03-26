#!/bin/sh
# advance-past.sh — Advance a past branch pin on the now branch.
#
# Updates the gitlink for a past submodule to point at a new commit and stages
# the change. Leaves the change staged for the operator to commit.
#
# The new commit must be a descendant of the current pin. If it is not,
# check-past-monotonicity.sh will reject the commit.
#
# Usage: advance-past.sh <past-submodule> <new-commit>
#   <past-submodule>  Full name of the past submodule (e.g. past/my-work)
#   <new-commit>      Any git commit, branch, or tag to advance to
#
# After running, review the staged change and commit with:
#   git commit -m "Advance <past-submodule>"

set -eu

USAGE="Usage: advance-past.sh <past-submodule> <new-commit>"

if [ "$#" -ne 2 ]; then
    echo "$USAGE" >&2
    exit 2
fi

PAST_SUB="$1"
NEW_COMMIT="$2"

# --- Preconditions ---

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not inside a git repository." >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
GITMODULES="$REPO_ROOT/.gitmodules"

if [ ! -f "$GITMODULES" ]; then
    echo "Error: .gitmodules not found. Run from the now branch." >&2
    exit 1
fi

# --- Verify past submodule exists and has role=past ---

PAST_ROLE=$(git config --file "$GITMODULES" "submodule.$PAST_SUB.role" 2>/dev/null || true)
if [ -z "$PAST_ROLE" ]; then
    echo "Error: submodule '$PAST_SUB' not found in .gitmodules." >&2
    exit 1
fi
if [ "$PAST_ROLE" != "past" ]; then
    echo "Error: '$PAST_SUB' has role '$PAST_ROLE' (must be past)." >&2
    exit 1
fi

# --- Resolve new commit ---

NEW_SHA=$(git rev-parse --verify "$NEW_COMMIT^{commit}" 2>/dev/null) || {
    echo "Error: commit not found: $NEW_COMMIT" >&2
    exit 1
}

# --- Read current pin from index ---

OLD_ENTRY=$(git ls-files --stage -- "$PAST_SUB" 2>/dev/null || true)
if [ -z "$OLD_ENTRY" ]; then
    echo "Error: no gitlink for $PAST_SUB in index." >&2
    echo "Hint: the submodule is declared in .gitmodules but has no pin." >&2
    exit 1
fi
OLD_SHA=$(printf '%s' "$OLD_ENTRY" | awk '{print $2}')

if [ "$OLD_SHA" = "$NEW_SHA" ]; then
    echo "  $PAST_SUB is already at $NEW_SHA. Nothing to do."
    exit 0
fi

echo "  Advancing $PAST_SUB"
echo "    from: $OLD_SHA"
echo "    to:   $NEW_SHA"

# --- Stage updated gitlink ---

git update-index --add --cacheinfo "160000,$NEW_SHA,$PAST_SUB"

echo ""
echo "Staged. Commit with:"
echo "  git commit -m \"Advance $PAST_SUB\""
