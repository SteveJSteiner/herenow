#!/bin/sh
# run.sh — GT12 test runner for provision-worktrees.sh.
# Creates fixture repos via init.sh, then tests worktree provisioning
# for idempotence, edge cases, and enforcement independence.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCAFFOLD_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROVISIONER="$SCAFFOLD_DIR/.now/src/provision-worktrees.sh"
INIT_SH="$SCAFFOLD_DIR/init.sh"
VALIDATOR="$SCAFFOLD_DIR/.now/src/validate-gitmodules.sh"

pass=0
fail=0

# --- Temp dir management ---

TMPDIRS=""
cleanup() {
    for d in $TMPDIRS; do
        rm -rf "$d" 2>/dev/null || true
    done
}
trap cleanup EXIT

new_dir() {
    _d=$(mktemp -d)
    TMPDIRS="$TMPDIRS $_d"
    printf '%s' "$_d"
}

# --- Test helpers ---

LAST_OUTPUT=""
LAST_RC=0

run_provision() {
    _repo="$1"
    set +e
    LAST_OUTPUT=$(cd "$_repo" && sh "$PROVISIONER" 2>&1)
    LAST_RC=$?
    set -e
}

run_init() {
    (cd "$1" && sh "$INIT_SH" >/dev/null 2>&1)
}

assert_eq() {
    _label="$1"
    _actual="$2"
    _expected="$3"
    if [ "$_actual" = "$_expected" ]; then
        echo "  PASS: $_label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $_label (expected '$_expected', got '$_actual')"
        echo "        output: $LAST_OUTPUT"
        fail=$((fail + 1))
    fi
}

assert_dir() {
    _label="$1"
    _path="$2"
    if [ -d "$_path" ]; then
        echo "  PASS: $_label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $_label (directory not found: $_path)"
        fail=$((fail + 1))
    fi
}

assert_no_dir() {
    _label="$1"
    _path="$2"
    if [ ! -d "$_path" ]; then
        echo "  PASS: $_label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $_label (directory should not exist: $_path)"
        fail=$((fail + 1))
    fi
}

assert_wt_branch() {
    _label="$1"
    _wt_path="$2"
    _expected="$3"
    _actual=$(git -C "$_wt_path" symbolic-ref --short HEAD 2>/dev/null || echo "")
    if [ "$_actual" = "$_expected" ]; then
        echo "  PASS: $_label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $_label (expected branch '$_expected', got '$_actual')"
        fail=$((fail + 1))
    fi
}

assert_msg() {
    _label="$1"
    _pattern="$2"
    case "$LAST_OUTPUT" in
        *"$_pattern"*)
            echo "  PASS: $_label"
            pass=$((pass + 1))
            ;;
        *)
            echo "  FAIL: $_label (expected '$_pattern' in output)"
            echo "        output: $LAST_OUTPUT"
            fail=$((fail + 1))
            ;;
    esac
}

# Create a fresh repo with scaffold files in HEAD (init.sh requires .now/ in HEAD).
new_repo() {
    _repo=$(new_dir)
    git -C "$_repo" init -q
    git -C "$_repo" config user.email "test@test"
    git -C "$_repo" config user.name "test"
    git -C "$_repo" config commit.gpgsign false
    # Copy scaffold enforcement files so init.sh step 5 can seed them.
    cp -r "$SCAFFOLD_DIR/.now" "$_repo/.now"
    git -C "$_repo" add .now
    git -C "$_repo" commit -q -m "scaffold"
    printf '%s' "$_repo"
}

# ===== Tests =====

echo "GT12 — worktree provisioning tests"
echo ""

# --- Test 1: Basic provisioning after init.sh ---

echo "--- 1. Basic provisioning (after init.sh) ---"

REPO=$(new_repo)
run_init "$REPO"

run_provision "$REPO"
assert_eq "exit code 0" "$LAST_RC" "0"
assert_dir "wt/meta created" "$REPO/wt/meta"
assert_wt_branch "wt/meta on meta branch" "$REPO/wt/meta" "meta"
assert_no_dir "wt/now not created (current branch)" "$REPO/wt/now"

echo ""

# --- Test 2: Idempotence ---

echo "--- 2. Idempotence (second run) ---"

run_provision "$REPO"
assert_eq "exit code 0 on re-run" "$LAST_RC" "0"
assert_dir "wt/meta still exists" "$REPO/wt/meta"
assert_wt_branch "wt/meta still on meta" "$REPO/wt/meta" "meta"
assert_msg "reports 0 created" "0 created"

echo ""

# --- Test 3: With past/future submodules ---

echo "--- 3. Past and future submodules ---"

REPO=$(new_repo)
run_init "$REPO"

# Create past and future branches from membrane root
_root=$(git -C "$REPO" rev-parse refs/membrane/root)
git -C "$REPO" branch rca0 "$_root"
git -C "$REPO" branch sls "$_root"

# Declare them in .gitmodules
cat > "$REPO/.gitmodules" <<'EOF'
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
EOF

run_provision "$REPO"
assert_eq "exit code 0" "$LAST_RC" "0"
assert_dir "wt/meta created" "$REPO/wt/meta"
assert_dir "wt/rca0 created" "$REPO/wt/rca0"
assert_dir "wt/sls created" "$REPO/wt/sls"
assert_wt_branch "wt/rca0 on rca0" "$REPO/wt/rca0" "rca0"
assert_wt_branch "wt/sls on sls" "$REPO/wt/sls" "sls"

echo ""

# --- Test 4: Missing branch ---

echo "--- 4. Missing branch (graceful skip) ---"

REPO=$(new_repo)
run_init "$REPO"

# Declare a submodule for a nonexistent branch
cat > "$REPO/.gitmodules" <<'EOF'
[submodule "meta"]
	path = meta
	url = ./
	role = meta
[submodule "ghost"]
	path = ghost
	url = ./
	role = past
EOF

run_provision "$REPO"
assert_eq "exit code 0" "$LAST_RC" "0"
assert_dir "wt/meta created" "$REPO/wt/meta"
assert_no_dir "wt/ghost not created" "$REPO/wt/ghost"
assert_msg "reports ghost not found" "ghost (branch not found)"

echo ""

# --- Test 5: Pre-existing path (not a worktree) ---

echo "--- 5. Pre-existing path (not a worktree) ---"

REPO=$(new_repo)
run_init "$REPO"
mkdir -p "$REPO/wt/meta"

run_provision "$REPO"
assert_eq "exit code 0" "$LAST_RC" "0"
# Should not have been overwritten — no .git file means not a worktree
if [ ! -f "$REPO/wt/meta/.git" ]; then
    echo "  PASS: wt/meta not overwritten"
    pass=$((pass + 1))
else
    echo "  FAIL: wt/meta was overwritten with a worktree"
    fail=$((fail + 1))
fi
assert_msg "reports path exists" "path exists, not a worktree"

echo ""

# --- Test 6: Not a membrane repo ---

echo "--- 6. Not a membrane repo (exit 2) ---"

PLAIN=$(new_dir)
git -C "$PLAIN" init -q
git -C "$PLAIN" config user.email "test@test"
git -C "$PLAIN" config user.name "test"
git -C "$PLAIN" config commit.gpgsign false
git -C "$PLAIN" commit -q --allow-empty -m "initial"

run_provision "$PLAIN"
assert_eq "exit code 2" "$LAST_RC" "2"
assert_msg "mentions membrane root" "refs/membrane/root"

echo ""

# --- Test 7: Enforcement works without worktrees ---

echo "--- 7. Enforcement without worktrees ---"

REPO=$(new_repo)
run_init "$REPO"

# Do NOT provision worktrees. Run the schema validator directly.
set +e
_vout=$(cd "$REPO" && sh "$VALIDATOR" 2>&1)
_vrc=$?
set -e
assert_eq "validate-gitmodules passes without worktrees" "$_vrc" "0"

echo ""

# --- Test 8: Provisioner from non-now branch ---

echo "--- 8. Provisioner from non-now branch ---"

REPO=$(new_repo)
_scaffold_br=$(git -C "$REPO" symbolic-ref --short HEAD)
run_init "$REPO"

# Switch to scaffold branch (now's .gitmodules won't be in working tree)
git -C "$REPO" checkout -q "$_scaffold_br"

run_provision "$REPO"
assert_eq "exit code 0" "$LAST_RC" "0"
# Should create wt/now (since we're on main, not now) and wt/meta
assert_dir "wt/now created (not current branch)" "$REPO/wt/now"
assert_dir "wt/meta created" "$REPO/wt/meta"
assert_wt_branch "wt/now on now" "$REPO/wt/now" "now"

echo ""

# --- Test 9: Gitignore hint ---

echo "--- 9. Gitignore hint shown when wt/ not ignored ---"

REPO=$(new_repo)
run_init "$REPO"

run_provision "$REPO"
assert_eq "exit code 0" "$LAST_RC" "0"
assert_msg "hint about gitignore" "add 'wt/' to .gitignore"

# Now add wt/ to .gitignore and re-run
echo "wt/" >> "$REPO/.gitignore"
# Remove existing worktrees so provisioner creates fresh ones
git -C "$REPO" worktree remove "$REPO/wt/meta" --force 2>/dev/null || true
run_provision "$REPO"
assert_msg "no hint when already ignored" "Provisioned:"
case "$LAST_OUTPUT" in
    *"add 'wt/' to .gitignore"*)
        echo "  FAIL: hint should not appear when wt/ is already in .gitignore"
        fail=$((fail + 1))
        ;;
    *)
        echo "  PASS: no gitignore hint when already ignored"
        pass=$((pass + 1))
        ;;
esac

echo ""

# --- Test 10: Works immediately after init.sh on fresh clone ---

echo "--- 10. Fresh repo: init then provision ---"

REPO=$(new_dir)
git -C "$REPO" init -q
git -C "$REPO" config user.email "test@test"
git -C "$REPO" config user.name "test"
git -C "$REPO" config commit.gpgsign false
cp -r "$SCAFFOLD_DIR/.now" "$REPO/.now"
echo "template" > "$REPO/README.md"
git -C "$REPO" add .now README.md
git -C "$REPO" commit -q -m "scaffold"
run_init "$REPO"

run_provision "$REPO"
assert_eq "exit code 0 on fresh repo" "$LAST_RC" "0"
assert_dir "wt/meta created on fresh repo" "$REPO/wt/meta"

echo ""

# --- Results ---

echo "=== Results ==="
echo "$pass passed, $fail failed."

if [ "$fail" -gt 0 ]; then
    exit 1
fi
