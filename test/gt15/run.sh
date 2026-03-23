#!/bin/sh
# run.sh — GT15 acceptance test: fresh-repo template to governed membrane.
#
# Validates the full operator path: template generation → init → bootstrap → governed.
# Tests both template creation paths (D32).
#
# GT15: Fresh-repo acceptance from GitHub template to governed membrane.

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
NOW_DIR="$REPO_ROOT/.now"

# Verify critical source files exist.
for _f in "$REPO_ROOT/init.sh" \
          "$NOW_DIR/hooks/pre-commit" \
          "$NOW_DIR/hooks/post-commit" \
          "$NOW_DIR/src/check-composition.sh" \
          "$NOW_DIR/src/validate-gitmodules.sh" \
          "$NOW_DIR/src/check-past-monotonicity.sh" \
          "$NOW_DIR/src/check-future-grounding.sh" \
          "$NOW_DIR/src/immune-response.sh" \
          "$NOW_DIR/src/check-meta-consistency.sh"; do
    if [ ! -f "$_f" ]; then
        echo "Error: required file not found: $_f" >&2
        exit 2
    fi
done

# ---------------------------------------------------------------------------
# Temp dir management
# ---------------------------------------------------------------------------

FIXTURE_A=""
FIXTURE_B=""

cleanup() {
    [ -n "$FIXTURE_A" ] && [ -d "$FIXTURE_A" ] && rm -rf "$FIXTURE_A"
    [ -n "$FIXTURE_B" ] && [ -d "$FIXTURE_B" ] && rm -rf "$FIXTURE_B"
}
trap cleanup EXIT

# ===================================================================
# Path A: Default-branch-only template (full acceptance)
# ===================================================================
# Simulates GitHub "Use this template" with default settings.
# GitHub creates a fresh repo with one commit containing the default
# branch's file contents — no history, no other branches, no custom refs.

test_path_a_pre_init() {
    echo "--- Path A.1: Pre-init state (default-branch-only)"

    FIXTURE_A="$(mktemp -d)"

    # Export main-branch file tree (no .git — simulates template generation)
    git -C "$REPO_ROOT" archive --format=tar HEAD | tar -x -C "$FIXTURE_A"

    cd "$FIXTURE_A"
    git init -q
    git config user.email "gt15@test.com"
    git config user.name "GT15 Acceptance"
    git add -A
    git commit -q -m "Initial commit from template"

    # D32: No membrane branches before init
    _branches=$(git branch --list 'now' 'meta' 'provenance/*' 2>/dev/null || true)
    if [ -z "$_branches" ]; then
        pass "no membrane branches before init"
    else
        fail "membrane branches found before init: $_branches"
    fi

    # D32: No refs/membrane/root before init
    if git rev-parse --verify refs/membrane/root >/dev/null 2>&1; then
        fail "refs/membrane/root exists before init"
    else
        pass "no refs/membrane/root before init"
    fi

    # Exactly one branch
    _count=$(git branch | wc -l | tr -d ' ')
    assert_eq "$_count" "1" "exactly one branch before init"

    # Template contents present
    if [ -f "init.sh" ] && [ -d ".now/hooks" ] && [ -d ".now/src" ]; then
        pass "template contents present (init.sh, .now/hooks, .now/src)"
    else
        fail "template contents missing"
    fi
}

test_path_a_init() {
    echo "--- Path A.2: Init"
    cd "$FIXTURE_A"

    rc=0
    sh ./init.sh >/dev/null 2>&1 || rc=$?
    assert_exit "$rc" 0 "init.sh exits 0"

    # On now branch after init
    _branch=$(git symbolic-ref --short HEAD)
    assert_eq "$_branch" "now" "on now branch after init"

    # Membrane root created
    if git rev-parse --verify refs/membrane/root >/dev/null 2>&1; then
        pass "refs/membrane/root created"
    else
        fail "refs/membrane/root missing after init"
    fi

    # Provenance recorded
    if git rev-parse --verify refs/heads/provenance/scaffold >/dev/null 2>&1; then
        pass "provenance/scaffold created"
    else
        fail "provenance/scaffold missing after init"
    fi

    # Now branch skeleton
    if [ -f "bootstrap.sh" ]; then
        pass "bootstrap.sh present on now"
    else
        fail "bootstrap.sh missing on now"
    fi

    if [ -f ".now/hooks/pre-commit" ] && [ -f ".now/hooks/post-commit" ]; then
        pass "hook stubs present on now"
    else
        fail "hook stubs missing on now"
    fi

    # Planning files seeded
    if [ -f "plan/requirements.md" ] && [ -f "plan/decisions.md" ] \
       && [ -f "plan/roadmap.md" ] && [ -f "plan/continuation.md" ]; then
        pass "planning files seeded"
    else
        fail "planning files missing"
    fi

    # Idempotent re-run (init.sh lives on provenance/scaffold, not on now;
    # test idempotency via source repo path — validates the logic, not the file location)
    rc=0
    _output=$(sh "$REPO_ROOT/init.sh" 2>&1) || rc=$?
    assert_exit "$rc" 0 "init.sh re-run exits 0"
    case "$_output" in
        *"Already initialized"*) pass "init.sh re-run detects already initialized" ;;
        *) fail "init.sh re-run did not detect already initialized" ;;
    esac
}

test_path_a_enforcement() {
    echo "--- Path A.3: Install enforcement"
    cd "$FIXTURE_A"

    # Install real enforcement from source repo onto now branch
    mkdir -p .now/src
    for _f in check-composition.sh validate-gitmodules.sh \
              check-past-monotonicity.sh check-future-grounding.sh \
              immune-response.sh check-meta-consistency.sh \
              provision-worktrees.sh; do
        cp "$NOW_DIR/src/$_f" .now/src/
    done

    for _h in post-commit post-merge post-rewrite pre-commit pre-merge-commit; do
        cp "$NOW_DIR/hooks/$_h" .now/hooks/
    done
    chmod +x .now/hooks/*

    # Update meta branch with enforcement manifest
    _manifest_file=$(mktemp)
    echo "# Enforcement manifest" > "$_manifest_file"
    for _f in .now/hooks/pre-commit .now/hooks/pre-merge-commit \
              .now/hooks/post-commit .now/hooks/post-merge .now/hooks/post-rewrite \
              .now/src/check-composition.sh .now/src/validate-gitmodules.sh \
              .now/src/check-past-monotonicity.sh .now/src/check-future-grounding.sh \
              .now/src/immune-response.sh .now/src/check-meta-consistency.sh; do
        _hash=$(git hash-object "$_f")
        echo "$_hash $_f" >> "$_manifest_file"
    done

    _meta_tip=$(git rev-parse refs/heads/meta)
    _tmpidx="$(git rev-parse --git-dir)/index.gt15.tmp"

    GIT_INDEX_FILE="$_tmpidx" git read-tree "$_meta_tip"
    _manifest_blob=$(git hash-object -w "$_manifest_file")
    rm -f "$_manifest_file"
    GIT_INDEX_FILE="$_tmpidx" git update-index --add --cacheinfo "100644,$_manifest_blob,enforcement-manifest"
    _new_tree=$(GIT_INDEX_FILE="$_tmpidx" git write-tree)
    _new_meta=$(git commit-tree "$_new_tree" -p "$_meta_tip" -m "Add enforcement manifest")
    git update-ref refs/heads/meta "$_new_meta"
    rm -f "$_tmpidx"

    # Update meta pin on now branch
    git update-index --add --cacheinfo "160000,$_new_meta,meta"

    # Stage and commit enforcement files (hooks not yet active — safe)
    git add .now/src/ .now/hooks/
    git commit -q -m "Install enforcement machinery"

    pass "enforcement machinery installed"
}

test_path_a_bootstrap() {
    echo "--- Path A.4: Bootstrap"
    cd "$FIXTURE_A"

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

test_path_a_governance() {
    echo "--- Path A.5: Governance is live"
    cd "$FIXTURE_A"

    # Build a minimal valid composition
    _root=$(git rev-parse refs/membrane/root)
    _blob=$(printf 'x' | git hash-object -w --stdin)
    _tree=$(printf '100644 blob %s\tfile\n' "$_blob" | git mktree)

    _p1=$(git commit-tree "$_tree" -p "$_root" -m "P1")
    _p2=$(git commit-tree "$_tree" -p "$_p1" -m "P2")
    git update-ref refs/heads/past1 "$_p2"

    _f1=$(git commit-tree "$_tree" -p "$_p1" -m "F1")
    git update-ref refs/heads/future1 "$_f1"

    # Declare composition in .gitmodules
    cat > .gitmodules <<'GITMOD'
[submodule "meta"]
	path = meta
	url = ./
	role = meta
[submodule "past1"]
	path = past1
	url = ./
	role = past
[submodule "future1"]
	path = future1
	url = ./
	role = future
	ancestor-constraint = past1
GITMOD

    git update-index --add --cacheinfo "160000,$_p2,past1"
    git update-index --add --cacheinfo "160000,$_f1,future1"
    git add .gitmodules

    # Valid composition — should succeed
    rc=0
    git commit -q -m "Valid composition" 2>/dev/null || rc=$?
    assert_exit "$rc" 0 "valid composition succeeds under governance"

    # Invalid composition — backward past pin — should be blocked
    _head_before=$(git rev-parse HEAD)
    git update-index --add --cacheinfo "160000,$_p1,past1"

    rc=0
    git commit -m "backward pin" 2>/dev/null || rc=$?
    if [ "$rc" -ne 0 ]; then
        pass "pre-commit blocks backward past pin"
    else
        fail "pre-commit did not block backward past pin"
    fi

    _head_after=$(git rev-parse HEAD)
    assert_eq "$_head_after" "$_head_before" "HEAD unchanged after blocked commit"
}

# ===================================================================
# Path B: "Include all branches" template (D32 validation)
# ===================================================================
# Simulates GitHub template with "Include all branches" checked.
# git clone copies refs/heads/* and refs/tags/* but NOT custom refs
# like refs/membrane/*. This is the same property GitHub templates use.

test_path_b() {
    echo "--- Path B: Include-all-branches template (D32)"

    FIXTURE_B="$(mktemp -d)"

    # Clone all branches from source repo (simulates "Include all branches")
    git clone -q "$REPO_ROOT" "$FIXTURE_B"
    cd "$FIXTURE_B"
    git config user.email "gt15@test.com"
    git config user.name "GT15 Acceptance"

    # Create local tracking branches for all remote branches
    for _remote in $(git branch -r | grep -v HEAD | sed 's|^ *origin/||'); do
        git branch "$_remote" "origin/$_remote" 2>/dev/null || true
    done

    # D32: refs/membrane/root NOT present (custom refs not propagated by clone)
    if git rev-parse --verify refs/membrane/root >/dev/null 2>&1; then
        fail "refs/membrane/root present in clone (D32 violation)"
    else
        pass "no refs/membrane/root in clone"
    fi

    # Branches from template may exist (now, meta, etc.)
    _has_now=false
    _has_meta=false
    git rev-parse --verify refs/heads/now >/dev/null 2>&1 && _has_now=true
    git rev-parse --verify refs/heads/meta >/dev/null 2>&1 && _has_meta=true

    if [ "$_has_now" = true ]; then
        pass "now branch present (expected from all-branches copy)"
    fi
    if [ "$_has_meta" = true ]; then
        pass "meta branch present (expected from all-branches copy)"
    fi

    # Key D32 property: without refs/membrane/root, no membrane topology exists
    # regardless of branch names. The branches are just regular branches.
    pass "D32 validated: all-branches clone has no membrane refs"
}

# ===================================================================
# Run all tests
# ===================================================================

echo "=== GT15 Acceptance Test — Template to Governed Membrane ==="
echo ""

test_path_a_pre_init
echo ""
test_path_a_init
echo ""
test_path_a_enforcement
echo ""
test_path_a_bootstrap
echo ""
test_path_a_governance
echo ""
test_path_b

echo ""
echo "=== Results: $PASS_COUNT passed, $FAIL_COUNT failed ==="

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
