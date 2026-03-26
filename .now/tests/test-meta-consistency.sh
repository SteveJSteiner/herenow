#!/bin/sh
# test-meta-consistency.sh — Validate meta self-consistency mechanism.
#
# Creates temporary repositories with meta branch, enforcement manifest,
# and gitlink pins, then exercises match/mismatch scenarios.
#
# Stress-test coverage:
#   1. Clean state (matching files) → pass
#   2. Modified hook file → detected → fail
#   3. Modified enforcement source → detected → fail
#   4. Clean state produces no false positives → pass
#   5. Advance meta pin to new SHA with matching content → pass
#   6. Advance meta pin to new SHA with different content → fail
#   7. Missing enforcement file → detected → fail
#   8. No meta submodule → skip gracefully → pass
#   9. Works without submodule init (implicit in all tests)
#
# GT11: Meta self-consistency mechanism.

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

assert_exit() {
    _actual="$1"
    _expected="$2"
    _msg="$3"
    if [ "$_actual" -eq "$_expected" ]; then
        pass "$_msg"
    else
        fail "$_msg (expected exit $_expected, got $_actual)"
    fi
}

cleanup() {
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Source location
# ---------------------------------------------------------------------------

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
NOW_DIR="$(cd "$SELF_DIR/.." && pwd)"
CHECKER="$NOW_DIR/src/check-meta-consistency.sh"

if [ ! -f "$CHECKER" ]; then
    echo "Error: checker not found: $CHECKER" >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Enforcement files to track (relative to repo root)
# ---------------------------------------------------------------------------

ENFORCEMENT_FILES="
.now/hooks/post-commit
.now/hooks/post-merge
.now/hooks/post-rewrite
.now/src/check-composition.sh
.now/src/validate-gitmodules.sh
.now/src/check-past-monotonicity.sh
.now/src/check-future-grounding.sh
.now/src/immune-response.sh
.now/src/check-meta-consistency.sh
"

# ---------------------------------------------------------------------------
# Setup: create a test repo with meta branch and enforcement files
# ---------------------------------------------------------------------------

# Generate an enforcement manifest from the current working tree files.
# Arguments: none (reads ENFORCEMENT_FILES, hashes files in $TEST_DIR)
# Output: manifest content on stdout
generate_manifest() {
    echo "# Enforcement manifest"
    for _rel in $ENFORCEMENT_FILES; do
        if [ -f "$TEST_DIR/$_rel" ]; then
            _hash=$(git hash-object "$TEST_DIR/$_rel")
            echo "$_hash $_rel"
        fi
    done
}

setup_repo() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    git config commit.gpgsign false

    # Capture default branch name (varies by git version and config).
    _default_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "master")

    # Initial commit.
    echo "init" > README
    git add README
    git commit -q -m "initial"

    # Copy enforcement files from the real repo.
    mkdir -p .now/hooks .now/src
    cp "$NOW_DIR/src/check-composition.sh" .now/src/
    cp "$NOW_DIR/src/validate-gitmodules.sh" .now/src/
    cp "$NOW_DIR/src/check-past-monotonicity.sh" .now/src/
    cp "$NOW_DIR/src/check-future-grounding.sh" .now/src/
    cp "$NOW_DIR/src/immune-response.sh" .now/src/
    cp "$NOW_DIR/src/check-meta-consistency.sh" .now/src/
    cp "$NOW_DIR/hooks/post-commit" .now/hooks/
    cp "$NOW_DIR/hooks/post-merge" .now/hooks/
    cp "$NOW_DIR/hooks/post-rewrite" .now/hooks/
    chmod +x .now/hooks/*

    # Commit enforcement files on default branch.
    git add .now/
    git commit -q -m "add enforcement"

    # Generate manifest from current enforcement files.
    _manifest=$(generate_manifest)

    # Create meta branch (orphan) with the manifest.
    git checkout -q --orphan meta
    git rm -rf . -q 2>/dev/null || true
    echo "# Meta" > README.md
    printf '%s\n' "$_manifest" > enforcement-manifest
    git add README.md enforcement-manifest
    git commit -q -m "meta with enforcement manifest"
    META_SHA=$(git rev-parse HEAD)

    # Return to default branch.
    git checkout -q "$_default_branch"

    # Add .gitmodules declaring meta submodule.
    cat > .gitmodules <<'GITMOD'
[submodule "meta"]
	path = meta
	url = ./
	role = meta
GITMOD

    # Register meta gitlink in index (no submodule init needed).
    git update-index --add --cacheinfo "160000,$META_SHA,meta"

    git add .gitmodules
    git commit -q -m "pin meta submodule"
}

# ---------------------------------------------------------------------------
# Test 1: Clean state — enforcement files match manifest
# ---------------------------------------------------------------------------

test_clean_state() {
    echo "--- Test 1: Clean state (matching files → pass)"
    setup_repo

    rc=0
    sh "$CHECKER" .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 0 "clean state passes consistency check"
}

# ---------------------------------------------------------------------------
# Test 2: Modified hook file → detected
# ---------------------------------------------------------------------------

test_modified_hook() {
    echo "--- Test 2: Modified hook file (detected → fail)"
    setup_repo

    # Modify a hook file in the working tree.
    echo "# tampered" >> .now/hooks/post-commit

    rc=0
    sh "$CHECKER" .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 1 "modified hook detected as inconsistent"
}

# ---------------------------------------------------------------------------
# Test 3: Modified enforcement source → detected
# ---------------------------------------------------------------------------

test_modified_source() {
    echo "--- Test 3: Modified enforcement source (detected → fail)"
    setup_repo

    # Modify a source file.
    echo "# tampered" >> .now/src/check-composition.sh

    rc=0
    sh "$CHECKER" .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 1 "modified source detected as inconsistent"
}

# ---------------------------------------------------------------------------
# Test 4: Clean state — no false positives (same as test 1, explicit)
# ---------------------------------------------------------------------------

test_no_false_positives() {
    echo "--- Test 4: Clean state — no false positives"
    setup_repo

    # Run checker multiple times to ensure stability.
    rc1=0; rc2=0; rc3=0
    sh "$CHECKER" .gitmodules >/dev/null 2>&1 || rc1=$?
    sh "$CHECKER" .gitmodules >/dev/null 2>&1 || rc2=$?
    sh "$CHECKER" .gitmodules >/dev/null 2>&1 || rc3=$?

    if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ] && [ "$rc3" -eq 0 ]; then
        pass "no false positives across 3 runs"
    else
        fail "false positive detected (exits: $rc1, $rc2, $rc3)"
    fi
}

# ---------------------------------------------------------------------------
# Test 5: Advance meta pin to new SHA with matching content → pass
# ---------------------------------------------------------------------------

test_advance_pin_matching() {
    echo "--- Test 5: Advance meta pin — matching content (pass)"
    setup_repo

    # Make a new commit on meta (change README, keep same manifest).
    git checkout -q meta
    echo "# Updated Meta README" > README.md
    git add README.md
    git commit -q -m "update meta readme"
    NEW_META_SHA=$(git rev-parse HEAD)
    git checkout -q -

    # Update the gitlink to the new meta SHA.
    git update-index --add --cacheinfo "160000,$NEW_META_SHA,meta"
    git add .gitmodules
    git commit -q -m "advance meta pin"

    # Enforcement files unchanged, manifest unchanged → should pass.
    rc=0
    sh "$CHECKER" .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 0 "advanced meta pin with matching content passes"
}

# ---------------------------------------------------------------------------
# Test 6: Advance meta pin to new SHA with different content → fail
# ---------------------------------------------------------------------------

test_advance_pin_different() {
    echo "--- Test 6: Advance meta pin — different content (fail)"
    setup_repo

    # Make a new commit on meta with a DIFFERENT manifest (wrong hash).
    git checkout -q meta
    cat > enforcement-manifest <<'MANIFEST'
# Enforcement manifest — with wrong hashes
0000000000000000000000000000000000000000 .now/hooks/post-commit
0000000000000000000000000000000000000000 .now/hooks/post-merge
MANIFEST
    git add enforcement-manifest
    git commit -q -m "meta with wrong manifest"
    NEW_META_SHA=$(git rev-parse HEAD)
    git checkout -q -

    # Update gitlink to point to the new meta.
    git update-index --add --cacheinfo "160000,$NEW_META_SHA,meta"
    git add .gitmodules
    git commit -q -m "advance meta pin to wrong manifest"

    # Enforcement files unchanged, but manifest hashes are wrong → should fail.
    rc=0
    sh "$CHECKER" .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 1 "advanced meta pin with different content fails"
}

# ---------------------------------------------------------------------------
# Test 7: Missing enforcement file → detected
# ---------------------------------------------------------------------------

test_missing_file() {
    echo "--- Test 7: Missing enforcement file (detected → fail)"
    setup_repo

    # Delete an enforcement file from the working tree.
    rm .now/src/immune-response.sh

    rc=0
    sh "$CHECKER" .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 1 "missing enforcement file detected"
}

# ---------------------------------------------------------------------------
# Test 8: No meta submodule → skip gracefully
# ---------------------------------------------------------------------------

test_no_meta_submodule() {
    echo "--- Test 8: No meta submodule (skip → pass)"

    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    git config commit.gpgsign false

    echo "init" > README
    git add README
    git commit -q -m "initial"

    # .gitmodules with no meta role.
    cat > .gitmodules <<'GITMOD'
[submodule "past-branch"]
	path = past-branch
	url = ./
	role = past
GITMOD
    git add .gitmodules
    git commit -q -m "non-meta submodules only"

    rc=0
    sh "$CHECKER" .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 0 "no meta submodule: checker skips gracefully"
}

# ---------------------------------------------------------------------------
# Test 9: No .gitmodules submodule entries → skip
# ---------------------------------------------------------------------------

test_empty_gitmodules() {
    echo "--- Test 9: Empty .gitmodules (skip → pass)"

    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    git config commit.gpgsign false

    echo "init" > README
    echo "# no submodules" > .gitmodules
    git add README .gitmodules
    git commit -q -m "initial"

    rc=0
    sh "$CHECKER" .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 0 "empty .gitmodules: checker skips gracefully"
}

# ---------------------------------------------------------------------------
# Test 10: Meta declared but not pinned → skip
# ---------------------------------------------------------------------------

test_meta_not_pinned() {
    echo "--- Test 10: Meta declared but not pinned (skip → pass)"

    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    git config commit.gpgsign false

    echo "init" > README
    cat > .gitmodules <<'GITMOD'
[submodule "meta"]
	path = meta
	url = ./
	role = meta
GITMOD
    git add README .gitmodules
    git commit -q -m "meta declared but no gitlink"

    rc=0
    sh "$CHECKER" .gitmodules >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 0 "meta declared but not pinned: checker skips"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

echo "=== Meta Self-Consistency Test Suite (GT11) ==="
echo ""

test_clean_state
echo ""
test_modified_hook
echo ""
test_modified_source
echo ""
test_no_false_positives
echo ""
test_advance_pin_matching
echo ""
test_advance_pin_different
echo ""
test_missing_file
echo ""
test_no_meta_submodule
echo ""
test_empty_gitmodules
echo ""
test_meta_not_pinned

echo ""
echo "=== Results: $PASS_COUNT passed, $FAIL_COUNT failed ==="

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
