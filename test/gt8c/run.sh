#!/bin/sh
# run.sh — GT8c test runner for check-composition.sh.
# Creates fixture repos with real git history and submodule gitlinks,
# then runs the atomic cross-check evaluator against various scenarios.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECKER="$SCRIPT_DIR/../../.now/src/check-composition.sh"

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

new_repo() {
    REPO=$(new_dir)
    build_history "$REPO"
}

# Write .gitmodules with one past + one future, stage both pins in index.
# Args: repo, past_name, future_name, past_pin, future_pin
setup_composition() {
    _repo="$1"
    _past="$2"
    _future="$3"
    _past_pin="$4"
    _future_pin="$5"

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

echo "GT8c — atomic cross-check tests"
echo ""

# --- Valid compositions (exit 0) ---

echo "--- Valid compositions (expect exit 0) ---"

new_repo
setup_composition "$REPO" rca0 sls "$SHA_P3" "$SHA_F2"
expect "clean new composition (past P3, future F2)" "$REPO" 0

new_repo
setup_composition "$REPO" rca0 sls "$SHA_P2" "$SHA_F2"
git -C "$REPO" commit -q -m "pin"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_P3,rca0"
expect "past advance P2→P3, future F2 stays grounded" "$REPO" 0

new_repo
setup_composition "$REPO" rca0 sls "$SHA_P2" "$SHA_F2"
git -C "$REPO" commit -q -m "pin"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_P3,rca0"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_F3,sls"
expect "past advance P2→P3 + future re-grounded F2→F3" "$REPO" 0

new_repo
cat > "$REPO/.gitmodules" <<EOF
[submodule "rca0"]
    path = rca0
    url = ./
    role = past
EOF
git -C "$REPO" add .gitmodules
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_P3,rca0"
expect "past-only composition (no futures)" "$REPO" 0

new_repo
cat > "$REPO/.gitmodules" <<EOF
EOF
git -C "$REPO" add .gitmodules
expect "empty .gitmodules (no submodules)" "$REPO" 0

echo ""

# --- Cross-constraint violations (exit 1) ---

echo "--- Cross-constraint violations (expect exit 1) ---"

# Past advances monotonically, but future is replaced with orphan → grounding breaks.
new_repo
setup_composition "$REPO" rca0 sls "$SHA_P2" "$SHA_F2"
git -C "$REPO" commit -q -m "pin"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_P3,rca0"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_O1,sls"
expect "past advance + orphan future (grounding breaks)" "$REPO" 1
expect_msg "cross: mentions no common ancestor" "no common ancestor"
expect_msg "cross: reports 1 check failed" "1 check(s) failed"

# Schema violation only — pins are valid but url is wrong.
# Monotonicity and grounding would pass on their own.
new_repo
cat > "$REPO/.gitmodules" <<EOF
[submodule "rca0"]
    path = rca0
    url = https://bad
    role = past
[submodule "sls"]
    path = sls
    url = https://bad
    role = future
    ancestor-constraint = rca0
EOF
git -C "$REPO" add .gitmodules
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_P3,rca0"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_F2,sls"
expect "schema violation only (url != ./)" "$REPO" 1
expect_msg "schema: reports 1 check failed" "1 check(s) failed"

# Only monotonicity fails — past goes backward, schema valid, future grounded.
new_repo
setup_composition "$REPO" rca0 sls "$SHA_P3" "$SHA_F2"
git -C "$REPO" commit -q -m "pin"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_P1,rca0"
expect "only monotonicity fails (P3→P1 backward)" "$REPO" 1
expect_msg "mono: mentions not a descendant" "not a descendant"
expect_msg "mono: reports 1 check failed" "1 check(s) failed"

echo ""

# --- Future retirement (exit 0) ---

echo "--- Future retirement (expect exit 0) ---"

# Commit a valid composition, then remove the future from .gitmodules and index.
new_repo
setup_composition "$REPO" rca0 sls "$SHA_P3" "$SHA_F2"
git -C "$REPO" commit -q -m "pin"
cat > "$REPO/.gitmodules" <<EOF
[submodule "rca0"]
    path = rca0
    url = ./
    role = past
EOF
git -C "$REPO" add .gitmodules
git -C "$REPO" update-index --force-remove sls
expect "retire future (removed from .gitmodules + index)" "$REPO" 0

echo ""

# --- Full error reporting (all checks fail) ---

echo "--- Full error reporting ---"

# Schema: url != "./" → fail.  Monotonicity: backward → fail.  Grounding: orphan → fail.
new_repo
cat > "$REPO/.gitmodules" <<EOF
[submodule "rca0"]
    path = rca0
    url = bad
    role = past
[submodule "sls"]
    path = sls
    url = bad
    role = future
    ancestor-constraint = rca0
EOF
git -C "$REPO" add .gitmodules
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_P3,rca0"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_F2,sls"
git -C "$REPO" commit -q -m "pin"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_P1,rca0"
git -C "$REPO" update-index --add --cacheinfo "160000,$SHA_O1,sls"
expect "all three checks fail" "$REPO" 1
expect_msg "all: reports 3 checks failed" "3 check(s) failed"
expect_msg "all: schema error present" "rule-4"
expect_msg "all: monotonicity error present" "not a descendant"
expect_msg "all: grounding error present" "no common ancestor"

echo ""

# --- Usage errors ---

echo "--- Usage errors (expect exit 2) ---"

EMPTY=$(new_dir)
git -C "$EMPTY" init -q
expect "file not found" "$EMPTY" 2

echo ""
echo "--- Results ---"
echo "$pass passed, $fail failed."

if [ "$fail" -gt 0 ]; then
    exit 1
fi
