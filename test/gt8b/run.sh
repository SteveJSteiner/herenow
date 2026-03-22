#!/bin/sh
# run.sh — GT8b test runner for check-future-grounding.sh.
# Creates fixture repos with real git history and submodule gitlinks,
# then runs the grounding checker against various scenarios.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECKER="$SCRIPT_DIR/../../.now/src/check-future-grounding.sh"

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
#
# Creates:
#   ROOT (empty) -> P1 -> P2 -> P3     (past line)
#   P2 -> F1 -> F2                      (future forked from mid-past)
#   P3 -> F3                            (future forked from past tip)
#   ROOT -> S1                           (shares only root with past)
#   [orphan] O1                          (completely unrelated)
#
# Sets: SHA_ROOT, SHA_P1, SHA_P2, SHA_P3, SHA_F1, SHA_F2, SHA_F3, SHA_S1, SHA_O1

build_history() {
    _repo="$1"
    git -C "$_repo" init -q
    git -C "$_repo" config user.email "test@test"
    git -C "$_repo" config user.name "test"

    # Root commit (empty, like membrane common root)
    git -C "$_repo" commit -q --allow-empty -m "root"
    SHA_ROOT=$(git -C "$_repo" rev-parse HEAD)

    # Past line: ROOT -> P1 -> P2 -> P3
    echo p1 > "$_repo/f"
    git -C "$_repo" add f
    git -C "$_repo" commit -q -m P1
    SHA_P1=$(git -C "$_repo" rev-parse HEAD)

    echo p2 > "$_repo/f"
    git -C "$_repo" add f
    git -C "$_repo" commit -q -m P2
    SHA_P2=$(git -C "$_repo" rev-parse HEAD)

    echo p3 > "$_repo/f"
    git -C "$_repo" add f
    git -C "$_repo" commit -q -m P3
    SHA_P3=$(git -C "$_repo" rev-parse HEAD)

    # Future forked from P2 (mid-past)
    git -C "$_repo" checkout -q "$SHA_P2"
    echo f1 > "$_repo/g"
    git -C "$_repo" add g
    git -C "$_repo" commit -q -m F1
    SHA_F1=$(git -C "$_repo" rev-parse HEAD)

    echo f2 > "$_repo/g"
    git -C "$_repo" add g
    git -C "$_repo" commit -q -m F2
    SHA_F2=$(git -C "$_repo" rev-parse HEAD)

    # Future forked from P3 (past tip)
    git -C "$_repo" checkout -q "$SHA_P3"
    echo f3 > "$_repo/h"
    git -C "$_repo" add h
    git -C "$_repo" commit -q -m F3
    SHA_F3=$(git -C "$_repo" rev-parse HEAD)

    # Branch sharing only root with past
    git -C "$_repo" checkout -q "$SHA_ROOT"
    echo s1 > "$_repo/s"
    git -C "$_repo" add s
    git -C "$_repo" commit -q -m S1
    SHA_S1=$(git -C "$_repo" rev-parse HEAD)

    # Completely unrelated history (orphan)
    git -C "$_repo" checkout -q --orphan orphan
    git -C "$_repo" rm -rf . >/dev/null 2>&1 || true
    echo o1 > "$_repo/o"
    git -C "$_repo" add o
    git -C "$_repo" commit -q -m O1
    SHA_O1=$(git -C "$_repo" rev-parse HEAD)

    # Return to known state
    git -C "$_repo" checkout -q "$SHA_P3"
}

# Fresh repo with commit history.
new_repo() {
    REPO=$(new_dir)
    build_history "$REPO"
}

# Write .gitmodules with one future + one past, stage both pins in index.
# Args: repo, future_name, past_name, future_pin, past_pin
setup_grounding() {
    _repo="$1"
    _future="$2"
    _past="$3"
    _future_pin="$4"
    _past_pin="$5"

    cat > "$_repo/.gitmodules" <<EOF
[submodule "$_past"]
    path = $_past
    url = ./
    role = past
[submodule "$_future"]
    path = $_future
    url = ./
    role = future
    ancestor-constraint = $_past
EOF
    git -C "$_repo" add .gitmodules
    git -C "$_repo" update-index --add --cacheinfo "160000,$_past_pin,$_past"
    git -C "$_repo" update-index --add --cacheinfo "160000,$_future_pin,$_future"
}

# ===== Tests =====

echo "GT8b — future grounding tests"
echo ""

# --- Valid cases ---

echo "--- Valid cases (expect exit 0) ---"

new_repo
setup_grounding "$REPO" sls rca0 "$SHA_F2" "$SHA_P3"
expect "future forked from early past (F2, past at P3)" "$REPO" 0

new_repo
setup_grounding "$REPO" sls rca0 "$SHA_F3" "$SHA_P3"
expect "future forked from past tip (F3, past at P3)" "$REPO" 0

new_repo
setup_grounding "$REPO" sls rca0 "$SHA_F2" "$SHA_P2"
expect "future forked from exact past pin (F2, past at P2)" "$REPO" 0

new_repo
setup_grounding "$REPO" sls rca0 "$SHA_P3" "$SHA_P3"
expect "future pinned at same commit as past" "$REPO" 0

new_repo
cat > "$REPO/.gitmodules" <<EOF
[submodule "rca0"]
    path = rca0
    url = ./
    role = past
EOF
git -C "$REPO" add .gitmodules
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_P3,rca0"
expect "no future submodules (past only)" "$REPO" 0

# Multiple futures grounded in different pasts
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
[submodule "sls"]
    path = sls
    url = ./
    role = future
    ancestor-constraint = rca0
[submodule "sls2"]
    path = sls2
    url = ./
    role = future
    ancestor-constraint = rca1
EOF
git -C "$REPO" add .gitmodules
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_P3,rca0"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_P2,rca1"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_F2,sls"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_F3,sls2"
expect "multiple futures grounded in different pasts" "$REPO" 0

echo ""

# --- Invalid cases + error messages ---

echo "--- Invalid cases (expect exit 1) ---"

new_repo
setup_grounding "$REPO" sls rca0 "$SHA_O1" "$SHA_P3"
expect "no common ancestor (orphan future)" "$REPO" 1
expect_msg "orphan: mentions future name" "'sls'"
expect_msg "orphan: mentions past name" "'rca0'"
expect_msg "orphan: mentions future pin" "$SHA_O1"
expect_msg "orphan: mentions past pin" "$SHA_P3"

new_repo
setup_grounding "$REPO" sls rca0 "$SHA_S1" "$SHA_P3"
expect "root-only shared ancestor" "$REPO" 1
expect_msg "root-only: mentions future name" "'sls'"
expect_msg "root-only: mentions 'root commit'" "root commit"

# Past has no pin in index
new_repo
cat > "$REPO/.gitmodules" <<EOF
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
git -C "$REPO" add .gitmodules
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_F2,sls"
expect "past has no pin in index" "$REPO" 1
expect_msg "no-pin: mentions future name" "'sls'"
expect_msg "no-pin: mentions ancestor-constraint" "'rca0'"

echo ""
echo "--- Results ---"
echo "$pass passed, $fail failed."

if [ "$fail" -gt 0 ]; then
    exit 1
fi
