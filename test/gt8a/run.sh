#!/bin/sh
# run.sh — GT8a test runner for check-past-monotonicity.sh.
# Creates fixture repos with real git history and submodule gitlinks,
# then runs the monotonicity checker against various scenarios.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECKER="$SCRIPT_DIR/../../.now/src/check-past-monotonicity.sh"

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

LAST_STDERR=""

expect() {
    _label="$1"
    _repo="$2"
    _expected="$3"

    set +e
    LAST_STDERR=$( cd "$_repo" && sh "$CHECKER" 2>&1 >/dev/null )
    _actual=$?
    set -e

    if [ "$_actual" -eq "$_expected" ]; then
        echo "  PASS: $_label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $_label (expected exit=$_expected, got exit=$_actual)"
        echo "        stderr: $LAST_STDERR"
        fail=$((fail + 1))
    fi
}

expect_msg() {
    _label="$1"
    _pattern="$2"

    case "$LAST_STDERR" in
        *"$_pattern"*)
            echo "  PASS: $_label"
            pass=$((pass + 1))
            ;;
        *)
            echo "  FAIL: $_label (expected '$_pattern' in output)"
            echo "        stderr: $LAST_STDERR"
            fail=$((fail + 1))
            ;;
    esac
}

# --- Build commit graph ---
# Creates: A -> B -> C (linear), A -> D (sibling)
# Sets global: SHA_A, SHA_B, SHA_C, SHA_D

build_history() {
    _repo="$1"
    git -C "$_repo" init -q
    git -C "$_repo" config user.email "test@test"
    git -C "$_repo" config user.name "test"
    git -C "$_repo" config commit.gpgsign false

    echo a > "$_repo/f"
    git -C "$_repo" add f
    git -C "$_repo" commit -q -m A
    SHA_A=$(git -C "$_repo" rev-parse HEAD)

    echo b > "$_repo/f"
    git -C "$_repo" add f
    git -C "$_repo" commit -q -m B
    SHA_B=$(git -C "$_repo" rev-parse HEAD)

    echo c > "$_repo/f"
    git -C "$_repo" add f
    git -C "$_repo" commit -q -m C
    SHA_C=$(git -C "$_repo" rev-parse HEAD)

    git -C "$_repo" checkout -q "$SHA_A"
    echo d > "$_repo/f"
    git -C "$_repo" add f
    git -C "$_repo" commit -q -m D
    SHA_D=$(git -C "$_repo" rev-parse HEAD)

    git -C "$_repo" checkout -q -
}

# Fresh repo with commit history.
# Sets: REPO, SHA_A, SHA_B, SHA_C, SHA_D
new_repo() {
    REPO=$(mktemp -d)
    TMPDIRS="$TMPDIRS $REPO"
    build_history "$REPO"
}

# Write .gitmodules with a single past submodule, commit old pin, stage new pin.
# Args: repo, name, old_pin ("" for newly added), new_pin
setup_past() {
    _repo="$1"
    _name="$2"
    _old="$3"
    _new="$4"

    cat > "$_repo/.gitmodules" <<EOF
[submodule "$_name"]
    path = $_name
    url = ./
    role = past
EOF
    git -C "$_repo" add .gitmodules

    if [ -n "$_old" ]; then
        git -C "$_repo" update-index --add --cacheinfo "160000,$_old,$_name"
        git -C "$_repo" commit -q -m "pin"
    else
        git -C "$_repo" commit -q -m "add"
    fi

    git -C "$_repo" update-index --add --cacheinfo "160000,$_new,$_name"
}

# ===== Tests =====

echo "GT8a — past monotonicity tests"
echo ""

# --- Valid cases ---

echo "--- Valid cases (expect exit 0) ---"

new_repo
setup_past "$REPO" "rca0" "$SHA_A" "$SHA_B"
expect "direct descendant (A→B)" "$REPO" 0

new_repo
setup_past "$REPO" "rca0" "$SHA_A" "$SHA_C"
expect "multi-step descendant (A→C)" "$REPO" 0

new_repo
setup_past "$REPO" "rca0" "" "$SHA_A"
expect "newly added (no old pin)" "$REPO" 0

new_repo
cat > "$REPO/.gitmodules" <<EOF
[submodule "sls"]
    path = sls
    url = ./
    role = future
EOF
git -C "$REPO" add .gitmodules
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_B,sls"
git -C "$REPO" commit -q -m "pin"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_A,sls"
expect "non-past role ignored" "$REPO" 0

echo ""

# --- Invalid cases + error messages ---

echo "--- Invalid cases (expect exit 1) ---"

new_repo
setup_past "$REPO" "rca0" "$SHA_B" "$SHA_A"
expect "backward (B→A)" "$REPO" 1
expect_msg "backward: mentions submodule name" "'rca0'"
expect_msg "backward: mentions old pin" "$SHA_B"
expect_msg "backward: mentions new pin" "$SHA_A"

new_repo
setup_past "$REPO" "rca0" "$SHA_B" "$SHA_D"
expect "sideways (B→D)" "$REPO" 1

new_repo
cat > "$REPO/.gitmodules" <<EOF
[submodule "rca0"]
    path = rca0
    url = ./
    role = past
[submodule "rca1"]
    path = rca1
    url = ./
    role = past
EOF
git -C "$REPO" add .gitmodules
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_A,rca0"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_B,rca1"
git -C "$REPO" commit -q -m "pin"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_B,rca0"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_A,rca1"
expect "mixed: one valid (A→B), one backward (B→A)" "$REPO" 1
expect_msg "mixed: error mentions violating submodule" "'rca1'"

echo ""
echo "--- Results ---"
echo "$pass passed, $fail failed."

if [ "$fail" -gt 0 ]; then
    exit 1
fi
