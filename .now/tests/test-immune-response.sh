#!/bin/sh
# test-immune-response.sh — Validate all immune-response hook paths.
#
# Creates a temporary repository, installs hooks, and exercises:
#   1. Normal violation → auto-revert (post-commit)
#   2. Clean commit → no response (post-commit)
#   3. Amend violation → single auto-revert, no double (post-commit + post-rewrite)
#   4. FF merge violation → auto-revert (post-merge)
#   5. No-ff merge violation → auto-revert -m 1 (post-merge)
#   6. Rebase violation → tag-and-refuse (post-rewrite)
#   7. Recursion guard → implicit in all auto-revert tests
#   8. Conflict-resolved merge → caught by post-commit
#
# GT10: Immune-response layer.

set -eu

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

PASS_COUNT=0
FAIL_COUNT=0
TEST_DIR=""

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "  PASS: $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  FAIL: $1" >&2
}

assert_eq() {
    if [ "$1" = "$2" ]; then
        pass "$3"
    else
        fail "$3 (expected '$2', got '$1')"
    fi
}

assert_contains() {
    if echo "$1" | grep -q "$2"; then
        pass "$3"
    else
        fail "$3 (output did not contain '$2')"
    fi
}

cleanup() {
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Source repo location (where the hooks and src live)
# ---------------------------------------------------------------------------

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
NOW_DIR="$(cd "$SELF_DIR/.." && pwd)"

# ---------------------------------------------------------------------------
# Setup: create a test repo with hooks installed
# ---------------------------------------------------------------------------

setup_repo() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    git config commit.gpgsign false
    # Capture default branch name for portability.
    _default_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "master")

    # Copy .now tree into the test repo.
    mkdir -p .now/hooks .now/src
    cp "$NOW_DIR/src/immune-response.sh" .now/src/
    cp "$NOW_DIR/src/check-composition.sh" .now/src/
    cp "$NOW_DIR/src/validate-gitmodules.sh" .now/src/
    cp "$NOW_DIR/src/check-past-monotonicity.sh" .now/src/
    cp "$NOW_DIR/src/check-future-grounding.sh" .now/src/
    cp "$NOW_DIR/hooks/post-commit" .now/hooks/
    cp "$NOW_DIR/hooks/post-merge" .now/hooks/
    cp "$NOW_DIR/hooks/post-rewrite" .now/hooks/
    chmod +x .now/hooks/*

    # Point git to our hooks.
    git config core.hooksPath .now/hooks

    # Initial clean commit (no .gitmodules = clean).
    echo "init" > README
    git add README
    git commit -q -m "initial"
}

# Create a valid .gitmodules (passes all checks).
write_clean_gitmodules() {
    # Empty .gitmodules or no submodule entries = passes validation.
    echo "# no submodules" > .gitmodules
}

# Create an invalid .gitmodules (fails schema validation).
write_bad_gitmodules() {
    cat > .gitmodules <<'GITMOD'
[submodule "bad"]
    path = bad
    url = https://example.com/bad.git
    role = INVALID_ROLE
GITMOD
}

# ---------------------------------------------------------------------------
# Test 1: Normal violation — auto-revert via post-commit
# ---------------------------------------------------------------------------

test_normal_violation() {
    echo "--- Test 1: Normal violation (post-commit auto-revert)"
    setup_repo

    write_bad_gitmodules
    git add .gitmodules
    # Use --no-verify to bypass pre-commit gate (simulating bypass).
    git commit -q --no-verify -m "violating commit" 2>/dev/null || true

    # The post-commit hook should have auto-reverted.
    # HEAD should be a revert commit. Check that HEAD message contains "Revert".
    head_msg="$(git log -1 --format=%s)"
    assert_contains "$head_msg" "Revert" "post-commit auto-reverted violation"

    # The .gitmodules should be back to the state before the violation.
    # (The revert undoes the violating commit's changes.)
    if [ -f .gitmodules ]; then
        # If .gitmodules exists, it should be clean (no bad role).
        if grep -q "INVALID_ROLE" .gitmodules 2>/dev/null; then
            fail "violation still present after revert"
        else
            pass "violation content removed after revert"
        fi
    else
        pass "violation content removed after revert (.gitmodules gone)"
    fi

    # Guard file should be cleaned up.
    git_dir="$(git rev-parse --git-dir)"
    if [ -f "$git_dir/MEMBRANE_REVERTING" ]; then
        fail "recursion guard not cleaned up"
    else
        pass "recursion guard cleaned up"
    fi
}

# ---------------------------------------------------------------------------
# Test 2: Clean commit — no response
# ---------------------------------------------------------------------------

test_clean_commit() {
    echo "--- Test 2: Clean commit (no response)"
    setup_repo

    echo "clean content" > file.txt
    git add file.txt
    git commit -q -m "clean commit" 2>/dev/null || true

    head_msg="$(git log -1 --format=%s)"
    assert_eq "$head_msg" "clean commit" "clean commit not reverted"

    commit_count="$(git rev-list --count HEAD)"
    assert_eq "$commit_count" "2" "no extra commits created"
}

# ---------------------------------------------------------------------------
# Test 3: Amend violation — single revert, no double
# ---------------------------------------------------------------------------

test_amend_violation() {
    echo "--- Test 3: Amend violation (no double revert)"
    setup_repo

    # First, make a clean commit.
    echo "base" > file.txt
    git add file.txt
    git commit -q -m "base commit" 2>/dev/null || true
    base_count="$(git rev-list --count HEAD)"

    # Now amend with a violation.
    write_bad_gitmodules
    git add .gitmodules
    git commit -q --amend --no-verify -m "amended with violation" 2>/dev/null || true

    # post-commit should have auto-reverted once.
    # post-rewrite (amend) should see MEMBRANE_VIOLATION_HANDLED and skip.
    head_msg="$(git log -1 --format=%s)"
    assert_contains "$head_msg" "Revert" "amend violation auto-reverted"

    # Count commits: base_count (before amend) was base_count.
    # After amend: base_count (amend replaces, so same count).
    # After revert: base_count + 1 (revert added).
    # Total should be base_count + 1 (one revert, not two).
    new_count="$(git rev-list --count HEAD)"
    expected=$((base_count + 1))
    assert_eq "$new_count" "$expected" "exactly one revert commit (no double revert)"

    # Handled marker should be cleaned up by post-rewrite.
    git_dir="$(git rev-parse --git-dir)"
    if [ -f "$git_dir/MEMBRANE_VIOLATION_HANDLED" ]; then
        fail "handled marker not cleaned up"
    else
        pass "handled marker cleaned up"
    fi
}

# ---------------------------------------------------------------------------
# Test 4: Fast-forward merge violation — auto-revert (post-merge)
# ---------------------------------------------------------------------------

test_ff_merge_violation() {
    echo "--- Test 4: FF merge violation (post-merge auto-revert)"
    setup_repo

    # Create a branch with a violation.
    git checkout -q -b bad-branch
    write_bad_gitmodules
    git add .gitmodules
    git commit -q --no-verify -m "bad on branch" 2>/dev/null || true
    # Revert the auto-revert so the branch tip has the violation.
    # (post-commit will have reverted it, so we need to undo that revert.)
    git reset -q --hard HEAD~1 2>/dev/null || true
    # Disable hooks temporarily to create the violating commit cleanly.
    git -c core.hooksPath=/dev/null commit -q --no-verify -m "bad on branch" -- .gitmodules 2>/dev/null || true

    # Go back to main and ff-merge.
    git checkout -q -
    git merge -q bad-branch 2>/dev/null || true

    # post-merge should have auto-reverted.
    head_msg="$(git log -1 --format=%s)"
    assert_contains "$head_msg" "Revert" "ff merge violation auto-reverted"
}

# ---------------------------------------------------------------------------
# Test 5: True merge (--no-ff) violation — auto-revert -m 1 (post-merge)
# ---------------------------------------------------------------------------

test_noff_merge_violation() {
    echo "--- Test 5: No-ff merge violation (post-merge auto-revert -m 1)"
    setup_repo

    # Create a branch with a violation (hooks disabled to keep the bad commit).
    git checkout -q -b bad-branch
    git -c core.hooksPath=/dev/null commit -q --allow-empty --no-verify -m "empty on branch" 2>/dev/null || true
    write_bad_gitmodules
    git add .gitmodules
    git -c core.hooksPath=/dev/null commit -q --no-verify -m "bad on branch" 2>/dev/null || true

    # Diverge main so merge is non-ff.
    git checkout -q -
    echo "diverge" > diverge.txt
    git add diverge.txt
    git commit -q -m "diverge main" 2>/dev/null || true

    # Merge --no-ff.
    git merge -q --no-ff bad-branch -m "merge bad-branch" 2>/dev/null || true

    # post-merge should have auto-reverted with -m 1.
    head_msg="$(git log -1 --format=%s)"
    assert_contains "$head_msg" "Revert" "no-ff merge violation auto-reverted"
}

# ---------------------------------------------------------------------------
# Test 6: Rebase violation — tag-and-refuse (post-rewrite)
# ---------------------------------------------------------------------------

test_rebase_violation() {
    echo "--- Test 6: Rebase violation (post-rewrite tag)"
    setup_repo

    # Create a branch with a violation (hooks disabled).
    git checkout -q -b feature
    write_bad_gitmodules
    git add .gitmodules
    git -c core.hooksPath=/dev/null commit -q --no-verify -m "bad on feature" 2>/dev/null || true

    # Advance main so rebase has work to do.
    git checkout -q -
    _default_br=$(git symbolic-ref --short HEAD)
    echo "advance" > advance.txt
    git add advance.txt
    git commit -q -m "advance main" 2>/dev/null || true

    # Rebase feature onto main.
    git checkout -q feature
    git rebase "$_default_br" 2>/dev/null || true

    # post-rewrite (rebase) should have tagged the violation.
    tag_list="$(git tag -l 'membrane/violation/*' 2>/dev/null)"
    if [ -n "$tag_list" ]; then
        pass "rebase violation tagged: $tag_list"
    else
        fail "rebase violation not tagged"
    fi

    # HEAD should NOT be a revert (rebase uses tag, not auto-revert).
    head_msg="$(git log -1 --format=%s)"
    if echo "$head_msg" | grep -q "Revert"; then
        fail "rebase violation was auto-reverted (should only tag)"
    else
        pass "rebase violation not auto-reverted (correct: tag only)"
    fi
}

# ---------------------------------------------------------------------------
# Test 7: Clean merge — no response
# ---------------------------------------------------------------------------

test_clean_merge() {
    echo "--- Test 7: Clean merge (no response)"
    setup_repo

    git checkout -q -b clean-branch
    echo "branch content" > branch.txt
    git add branch.txt
    git commit -q -m "clean on branch" 2>/dev/null || true

    git checkout -q -
    echo "main content" > main.txt
    git add main.txt
    git commit -q -m "clean on main" 2>/dev/null || true

    # Use first-parent count (rev-list --count includes both merge parents).
    pre_count="$(git rev-list --first-parent --count HEAD)"
    git merge -q --no-ff clean-branch -m "merge clean-branch" 2>/dev/null || true
    post_count="$(git rev-list --first-parent --count HEAD)"

    # Should have exactly 1 new first-parent commit (the merge), no revert.
    expected=$((pre_count + 1))
    assert_eq "$post_count" "$expected" "clean merge: no extra commits"

    head_msg="$(git log -1 --format=%s)"
    assert_eq "$head_msg" "merge clean-branch" "clean merge: commit message intact"
}

# ---------------------------------------------------------------------------
# Test 8: Conflict-resolved merge — caught by post-commit
# ---------------------------------------------------------------------------

test_conflict_merge_violation() {
    echo "--- Test 8: Conflict-resolved merge violation (post-commit)"
    setup_repo

    # Create .gitmodules on main (clean — just a comment).
    echo "# main version" > .gitmodules
    git add .gitmodules
    git commit -q -m "gitmodules on main" 2>/dev/null || true

    # Create branch with bad .gitmodules (hooks disabled for setup).
    git checkout -q -b conflict-branch
    write_bad_gitmodules
    git -c core.hooksPath=/dev/null commit -q --no-verify -a -m "bad gitmodules on branch" 2>/dev/null || true

    # Diverge main so merge produces a conflict.
    git checkout -q -
    echo "# different main version" > .gitmodules
    git add .gitmodules
    git commit -q -m "different gitmodules on main" 2>/dev/null || true

    # Start merge — will conflict on .gitmodules.
    git merge conflict-branch 2>/dev/null || true

    # Resolve conflict with the bad version. Hooks are active for this commit.
    # --no-verify bypasses pre-commit but post-commit still fires.
    write_bad_gitmodules
    git add .gitmodules
    git commit --no-verify -m "resolved conflict (bad)" 2>/dev/null || true

    # post-commit fires for conflict-resolved merge. Should auto-revert.
    head_msg="$(git log -1 --format=%s)"
    assert_contains "$head_msg" "Revert" "conflict-resolved merge violation caught by post-commit"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

echo "=== Immune-Response Test Suite (GT10) ==="
echo ""

test_normal_violation
echo ""
test_clean_commit
echo ""
test_amend_violation
echo ""
test_ff_merge_violation
echo ""
test_noff_merge_violation
echo ""
test_rebase_violation
echo ""
test_clean_merge
echo ""
test_conflict_merge_violation

echo ""
echo "=== Results: $PASS_COUNT passed, $FAIL_COUNT failed ==="

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
