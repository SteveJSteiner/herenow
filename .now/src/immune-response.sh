#!/bin/sh
# immune-response.sh — Shared immune-response logic for post-hooks.
#
# Provides detection (run constraint evaluator) and response (auto-revert
# or tag-and-refuse-next) functions used by post-commit, post-merge, and
# post-rewrite hooks.
#
# Sourced by hook scripts, not executed directly.
#
# GT10: Immune-response layer.

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

# SRC_DIR must be set by the caller (hook script) before sourcing.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
GIT_DIR="$(git rev-parse --git-dir 2>/dev/null)"

EVALUATOR="$SRC_DIR/check-composition.sh"
GUARD_FILE="$GIT_DIR/MEMBRANE_REVERTING"
HANDLED_MARKER="$GIT_DIR/MEMBRANE_VIOLATION_HANDLED"

# ---------------------------------------------------------------------------
# Recursion guard
# ---------------------------------------------------------------------------

membrane_guard_active() {
    [ -f "$GUARD_FILE" ]
}

membrane_guard_set() {
    echo "$$" > "$GUARD_FILE"
}

membrane_guard_clear() {
    rm -f "$GUARD_FILE"
}

# ---------------------------------------------------------------------------
# Coordination marker (post-commit ↔ post-rewrite for amend)
# ---------------------------------------------------------------------------

membrane_handled_set() {
    echo "$$" > "$HANDLED_MARKER"
}

membrane_handled_check() {
    [ -f "$HANDLED_MARKER" ]
}

membrane_handled_clear() {
    rm -f "$HANDLED_MARKER"
}

# ---------------------------------------------------------------------------
# Rebase detection
# ---------------------------------------------------------------------------

membrane_rebase_active() {
    [ -d "$GIT_DIR/rebase-merge" ] || [ -d "$GIT_DIR/rebase-apply" ]
}

# ---------------------------------------------------------------------------
# Merge commit detection
# ---------------------------------------------------------------------------

membrane_is_merge_commit() {
    _parents="$(git cat-file -p HEAD 2>/dev/null | grep -c '^parent ')"
    [ "$_parents" -gt 1 ]
}

# ---------------------------------------------------------------------------
# Detection — run the constraint evaluator
# ---------------------------------------------------------------------------

membrane_check_violation() {
    if [ ! -f "$EVALUATOR" ]; then
        echo "membrane: evaluator not found: $EVALUATOR" >&2
        return 1
    fi
    # No .gitmodules = no submodules = clean composition.
    if [ ! -f "$REPO_ROOT/.gitmodules" ]; then
        return 0
    fi
    sh "$EVALUATOR" "$REPO_ROOT/.gitmodules" >/dev/null 2>&1
    return $?
}

# ---------------------------------------------------------------------------
# Response: auto-revert
# ---------------------------------------------------------------------------

membrane_auto_revert() {
    _revert_flags="${1:-}"  # e.g. "-m 1" for merge commits

    echo "membrane: VIOLATION DETECTED — auto-reverting HEAD" >&2

    membrane_guard_set

    if [ -n "$_revert_flags" ]; then
        # shellcheck disable=SC2086
        git revert --no-edit $_revert_flags HEAD 2>&1 | sed 's/^/membrane: /' >&2
    else
        git revert --no-edit HEAD 2>&1 | sed 's/^/membrane: /' >&2
    fi
    _rc=$?

    # For amend coordination: leave handled marker so post-rewrite skips.
    membrane_handled_set

    membrane_guard_clear

    if [ $_rc -ne 0 ]; then
        echo "membrane: auto-revert FAILED (exit $_rc) — manual intervention required" >&2
        return 1
    fi

    echo "membrane: violation reverted. The violating commit has been undone." >&2
    return 0
}

# ---------------------------------------------------------------------------
# Response: tag-and-refuse-next
# ---------------------------------------------------------------------------

membrane_tag_violation() {
    _sha="$(git rev-parse --short HEAD 2>/dev/null)"
    _tag="membrane/violation/$_sha"

    echo "membrane: VIOLATION DETECTED — tagging HEAD as $_tag" >&2

    git tag "$_tag" HEAD 2>&1 | sed 's/^/membrane: /' >&2
    _rc=$?

    if [ $_rc -ne 0 ]; then
        echo "membrane: tagging FAILED (exit $_rc)" >&2
        return 1
    fi

    echo "membrane: violation tagged. Next governed operation will refuse until resolved." >&2
    return 0
}
