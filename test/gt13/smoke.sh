#!/bin/sh
# smoke.sh — GT13 end-to-end smoke test.
#
# Builds a complete membrane fixture repo from scratch and exercises
# the full lifecycle: init → enforcement → bootstrap → compositions.
#
# Scenarios:
#   1. Init + Bootstrap
#   2. Valid composition
#   3. Invalid composition (pre-commit block)
#   4. Bypass + immune response
#   5. Worktree provisioning
#   6. Meta consistency
#
# GT13: End-to-end fixture repo and smoke scenarios.

set -eu

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

PASS_COUNT=0
FAIL_COUNT=0

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

assert_exit() {
    if [ "$1" -eq "$2" ]; then
        pass "$3"
    else
        fail "$3 (expected exit $2, got $1)"
    fi
}

# ---------------------------------------------------------------------------
# Source repo location
# ---------------------------------------------------------------------------

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/../.." && pwd)"
INIT_SH="$REPO_ROOT/init.sh"
NOW_DIR="$REPO_ROOT/.now"

# Verify critical source files exist.
for _f in "$INIT_SH" \
          "$NOW_DIR/hooks/pre-commit" \
          "$NOW_DIR/hooks/pre-merge-commit" \
          "$NOW_DIR/hooks/post-commit" \
          "$NOW_DIR/hooks/post-merge" \
          "$NOW_DIR/hooks/post-rewrite" \
          "$NOW_DIR/src/check-composition.sh" \
          "$NOW_DIR/src/validate-gitmodules.sh" \
          "$NOW_DIR/src/check-past-monotonicity.sh" \
          "$NOW_DIR/src/check-future-grounding.sh" \
          "$NOW_DIR/src/immune-response.sh" \
          "$NOW_DIR/src/check-meta-consistency.sh" \
          "$NOW_DIR/src/provision-worktrees.sh" \
          "$NOW_DIR/src/create-past.sh" \
          "$NOW_DIR/src/create-future.sh" \
          "$NOW_DIR/src/advance-past.sh" \
          "$NOW_DIR/src/graduate-future.sh" \
          "$NOW_DIR/src/update-manifest.sh"; do
    if [ ! -f "$_f" ]; then
        echo "Error: required file not found: $_f" >&2
        exit 2
    fi
done

# ---------------------------------------------------------------------------
# Temp dir management
# ---------------------------------------------------------------------------

FIXTURE=""

cleanup() {
    if [ -n "$FIXTURE" ] && [ -d "$FIXTURE" ]; then
        rm -rf "$FIXTURE"
    fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Shared state (populated by scenarios, used across scenarios)
# ---------------------------------------------------------------------------

P1=""
P2=""
P3=""
F1=""

# ===================================================================
# Scenario 1: Init + Bootstrap
# ===================================================================

test_init_bootstrap() {
    echo "--- Scenario 1: Init + Bootstrap"

    FIXTURE="$(mktemp -d)"
    cd "$FIXTURE"
    git init -q
    git config user.email "smoke@test.com"
    git config user.name "Smoke Test"
    git config commit.gpgsign false
    # Copy scaffold enforcement files so init.sh step 5 can seed them.
    cp -r "$NOW_DIR" .now
    echo "seed" > README.md
    git add .now README.md
    git commit -q -m "initial seed"

    # --- Run init.sh ---

    rc=0
    sh "$INIT_SH" >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 0 "init.sh exits 0"

    _branch=$(git symbolic-ref --short HEAD)
    assert_eq "$_branch" "now" "on now branch after init"

    if git rev-parse --verify refs/membrane/root >/dev/null 2>&1; then
        pass "refs/membrane/root exists"
    else
        fail "refs/membrane/root missing"
    fi

    if [ -f ".now/hooks/pre-commit" ] && [ -f ".now/hooks/post-commit" ]; then
        pass "hook stubs present"
    else
        fail "hook stubs missing"
    fi

    if [ -f "bootstrap.sh" ]; then
        pass "bootstrap.sh present"
    else
        fail "bootstrap.sh missing"
    fi

    # --- Run bootstrap.sh ---

    rc=0
    sh bootstrap.sh >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 0 "bootstrap.sh exits 0"

    _hp=$(git config core.hooksPath || true)
    assert_eq "$_hp" ".now/hooks" "core.hooksPath set"

    if [ -d "meta" ] && [ -n "$(ls -A meta 2>/dev/null)" ]; then
        pass "meta submodule initialized"
    else
        fail "meta submodule not initialized"
    fi

    if [ -f ".now/src/check-composition.sh" ]; then
        pass "constraint evaluator reachable"
    else
        fail "constraint evaluator not found"
    fi
}

# ===================================================================
# Scenario 2: Valid composition
# ===================================================================

test_valid_composition() {
    echo "--- Scenario 2: Valid composition"
    cd "$FIXTURE"

    # Build past branch: root → P1 → P2 → P3
    _root=$(git rev-parse refs/membrane/root)
    _blob=$(printf 'x' | git hash-object -w --stdin)
    _tree=$(printf '100644 blob %s\tfile\n' "$_blob" | git mktree)

    P1=$(git commit-tree "$_tree" -p "$_root" -m "P1")
    P2=$(git commit-tree "$_tree" -p "$P1" -m "P2")
    P3=$(git commit-tree "$_tree" -p "$P2" -m "P3")
    git update-ref refs/heads/rca0 "$P3"

    # Build future branch: fork from P2 → F1
    F1=$(git commit-tree "$_tree" -p "$P2" -m "F1")
    git update-ref refs/heads/sls "$F1"

    # Declare composition in .gitmodules
    cat > .gitmodules <<'GITMOD'
[submodule "meta"]
	path = meta
	url = ./
	role = meta
[submodule "rca0"]
	path = rca0
	url = ./
	role = past
[submodule "sls"]
	path = sls
	url = ./
	role = future
	ancestor-constraint = rca0
GITMOD

    # Stage gitlinks and .gitmodules
    git update-index --add --cacheinfo "160000,$P3,rca0"
    git update-index --add --cacheinfo "160000,$F1,sls"
    git add .gitmodules

    # Commit — pre-commit hook active, should pass all constraints
    rc=0
    git commit -q -m "Valid temporal composition" 2>/dev/null || rc=$?
    assert_exit "$rc" 0 "valid composition commit succeeds"

    _head_msg=$(git log -1 --format=%s)
    assert_eq "$_head_msg" "Valid temporal composition" "commit message intact (no revert)"

    # No immune response triggered
    _log=$(git log --oneline -3)
    if echo "$_log" | grep -q "Revert"; then
        fail "unexpected revert in log"
    else
        pass "no immune response triggered"
    fi
}

# ===================================================================
# Scenario 3: Invalid composition (pre-commit block)
# ===================================================================

test_invalid_precommit() {
    echo "--- Scenario 3: Invalid composition (pre-commit block)"
    cd "$FIXTURE"

    _head_before=$(git rev-parse HEAD)

    # Stage backward past pin: rca0 → P1 (was P3)
    git update-index --add --cacheinfo "160000,$P1,rca0"

    # Attempt commit — pre-commit should block (monotonicity violation)
    rc=0
    git commit -m "backward past pin" 2>/dev/null || rc=$?

    if [ "$rc" -ne 0 ]; then
        pass "pre-commit blocked invalid composition (exit $rc)"
    else
        fail "pre-commit did NOT block invalid composition"
    fi

    # HEAD unchanged
    _head_after=$(git rev-parse HEAD)
    assert_eq "$_head_after" "$_head_before" "HEAD unchanged after blocked commit"
}

# ===================================================================
# Scenario 4: Bypass + immune response
# ===================================================================

test_bypass_immune_response() {
    echo "--- Scenario 4: Bypass + immune response"
    cd "$FIXTURE"

    # Reset rca0 gitlink to P3 (undo scenario 3's stale index entry)
    git update-index --add --cacheinfo "160000,$P3,rca0"

    # Write invalid .gitmodules (schema violation: bad role)
    cat > .gitmodules <<'GITMOD'
[submodule "meta"]
	path = meta
	url = ./
	role = meta
[submodule "rca0"]
	path = rca0
	url = ./
	role = INVALID
[submodule "sls"]
	path = sls
	url = ./
	role = future
	ancestor-constraint = rca0
GITMOD
    git add .gitmodules

    _count_before=$(git rev-list --count HEAD)

    # Commit with --no-verify (bypass pre-commit)
    git commit -q --no-verify -m "bypassed: invalid role" 2>/dev/null || true

    # Post-commit should detect schema violation and auto-revert
    _head_msg=$(git log -1 --format=%s)
    assert_contains "$_head_msg" "Revert" "post-commit auto-reverted bypass"

    # Violating commit exists in history
    _parent_msg=$(git log -1 --skip=1 --format=%s)
    assert_eq "$_parent_msg" "bypassed: invalid role" "violating commit in log"

    # Exactly 2 new commits (violation + revert)
    _count_after=$(git rev-list --count HEAD)
    _expected=$((_count_before + 2))
    assert_eq "$_count_after" "$_expected" "exactly 2 new commits (violation + revert)"

    # .gitmodules restored (no invalid role)
    if grep -q "INVALID" .gitmodules 2>/dev/null; then
        fail ".gitmodules not restored after revert"
    else
        pass ".gitmodules restored after revert"
    fi

    # Guard file cleaned up
    _git_dir=$(git rev-parse --git-dir)
    if [ -f "$_git_dir/MEMBRANE_REVERTING" ]; then
        fail "recursion guard not cleaned up"
    else
        pass "recursion guard cleaned up"
    fi
}

# ===================================================================
# Scenario 5: Worktree provisioning
# ===================================================================

test_worktree_provisioning() {
    echo "--- Scenario 5: Worktree provisioning"
    cd "$FIXTURE"

    rc=0
    sh .now/src/provision-worktrees.sh >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 0 "provision-worktrees.sh exits 0"

    if [ -d "wt/meta" ]; then
        pass "wt/meta created"
    else
        fail "wt/meta not created"
    fi

    if [ -d "wt/rca0" ]; then
        pass "wt/rca0 created"
    else
        fail "wt/rca0 not created"
    fi

    if [ -d "wt/sls" ]; then
        pass "wt/sls created"
    else
        fail "wt/sls not created"
    fi

    _meta_branch=$(cd wt/meta && git symbolic-ref --short HEAD 2>/dev/null)
    assert_eq "$_meta_branch" "meta" "wt/meta on meta branch"

    _rca0_branch=$(cd wt/rca0 && git symbolic-ref --short HEAD 2>/dev/null)
    assert_eq "$_rca0_branch" "rca0" "wt/rca0 on rca0 branch"

    _sls_branch=$(cd wt/sls && git symbolic-ref --short HEAD 2>/dev/null)
    assert_eq "$_sls_branch" "sls" "wt/sls on sls branch"
}

# ===================================================================
# Scenario 6: Meta consistency
# ===================================================================

test_meta_consistency() {
    echo "--- Scenario 6: Meta consistency"
    cd "$FIXTURE"

    # Enforcement files should match manifest
    rc=0
    sh .now/src/check-meta-consistency.sh .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 0 "meta consistency passes"

    # Tamper and verify detection
    echo "# tampered" >> .now/src/check-composition.sh

    rc=0
    sh .now/src/check-meta-consistency.sh .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 1 "meta consistency detects tampering"

    # Restore and verify
    cp "$NOW_DIR/src/check-composition.sh" .now/src/check-composition.sh

    rc=0
    sh .now/src/check-meta-consistency.sh .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 0 "meta consistency passes after restore"
}

# ===================================================================
# Scenario 7: update-manifest.sh
# ===================================================================

test_update_manifest() {
    echo "--- Scenario 7: update-manifest.sh"
    cd "$FIXTURE"

    # Tamper with an enforcement file to put it out of sync with the manifest.
    echo "# modified" >> .now/src/check-composition.sh

    # Meta consistency should now fail (manifest mismatch).
    rc=0
    sh .now/src/check-meta-consistency.sh .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 1 "meta consistency detects modified enforcement file"

    # Run update-manifest.sh — should regenerate manifest and stage new meta pin.
    rc=0
    sh .now/src/update-manifest.sh >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 0 "update-manifest.sh exits 0"

    # Meta consistency should pass against working tree now.
    rc=0
    sh .now/src/check-meta-consistency.sh .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 0 "meta consistency passes after update-manifest"

    # The staged meta gitlink should point to a new meta tip.
    _staged_meta=$(git ls-files --stage -- meta 2>/dev/null | awk '{print $2}')
    _meta_tip=$(git rev-parse refs/heads/meta)
    assert_eq "$_staged_meta" "$_meta_tip" "staged meta gitlink matches new meta tip"

    # Committing the result should succeed (pre-commit passes with new manifest).
    # update-manifest.sh stages the enforcement files — no manual git add needed.
    rc=0
    git commit -q -m "Update enforcement source via update-manifest" 2>/dev/null || rc=$?
    assert_exit "$rc" 0 "commit with updated manifest succeeds"

    # No immune response triggered.
    _head_msg=$(git log -1 --format=%s)
    assert_eq "$_head_msg" "Update enforcement source via update-manifest" \
        "no auto-revert after update-manifest commit"
}

# ===================================================================
# Run all scenarios
# ===================================================================

echo "=== GT13 Smoke Test — End-to-End ==="
echo ""

test_init_bootstrap
echo ""
test_valid_composition
echo ""
test_invalid_precommit
echo ""
test_bypass_immune_response
echo ""
test_worktree_provisioning
echo ""
test_meta_consistency
echo ""
test_update_manifest

echo ""
echo "=== Results: $PASS_COUNT passed, $FAIL_COUNT failed ==="

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
