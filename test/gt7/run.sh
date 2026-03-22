#!/bin/sh
# run.sh — GT7 test runner for validate-gitmodules.sh.
# Runs the validator against each fixture and checks exit codes + error messages.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR="$SCRIPT_DIR/../../.now/src/validate-gitmodules.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

pass=0
fail=0

# Run validator, check exit code.
expect() {
    _fixture="$1"
    _expected="$2"
    _label="$3"

    set +e
    _stderr=$(sh "$VALIDATOR" "$FIXTURES/$_fixture" 2>&1 >/dev/null)
    _actual=$?
    set -e

    if [ "$_actual" -eq "$_expected" ]; then
        echo "  PASS: $_label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $_label (expected exit=$_expected, got exit=$_actual)"
        echo "        stderr: $_stderr"
        fail=$((fail + 1))
    fi
}

# Run validator, check that stderr contains a substring.
expect_msg() {
    _fixture="$1"
    _pattern="$2"
    _label="$3"

    set +e
    _stderr=$(sh "$VALIDATOR" "$FIXTURES/$_fixture" 2>&1 >/dev/null)
    set -e

    case "$_stderr" in
        *"$_pattern"*)
            echo "  PASS: $_label"
            pass=$((pass + 1))
            ;;
        *)
            echo "  FAIL: $_label (expected '$_pattern' in output)"
            echo "        stderr: $_stderr"
            fail=$((fail + 1))
            ;;
    esac
}

echo "GT7 — validate-gitmodules tests"
echo ""

echo "--- Valid cases (expect exit 0) ---"
expect "empty.gitmodules"       0 "empty file (no submodules)"
expect "valid-meta-only.gitmodules" 0 "single meta entry (init state)"
expect "valid-full.gitmodules"  0 "meta + past + future"
expect "valid-multi.gitmodules" 0 "multiple pasts, multiple futures"

echo ""
echo "--- Invalid cases (expect exit 1) ---"
expect "invalid-missing-role.gitmodules"              1 "rule 1: missing role"
expect "invalid-bad-role.gitmodules"                  1 "rule 1: invalid role value"
expect "invalid-future-no-ancestor.gitmodules"        1 "rule 2: future without ancestor-constraint"
expect "invalid-future-nonexistent-ancestor.gitmodules" 1 "rule 2: ancestor names nonexistent submodule"
expect "invalid-future-meta-ancestor.gitmodules"      1 "rule 2: ancestor names meta submodule"
expect "invalid-future-future-ancestor.gitmodules"    1 "rule 2: ancestor names future submodule"
expect "invalid-past-with-ancestor.gitmodules"        1 "rule 3: past with ancestor-constraint"
expect "invalid-meta-with-ancestor.gitmodules"        1 "rule 3: meta with ancestor-constraint"
expect "invalid-url.gitmodules"                       1 "rule 4: url != ./"
expect "invalid-path-mismatch.gitmodules"             1 "rule 5: path != name"
expect "invalid-duplicate-path.gitmodules"            1 "rule 6: duplicate paths"

echo ""
echo "--- Error message checks ---"
expect_msg "invalid-missing-role.gitmodules"           "rule-1"       "mentions rule-1"
expect_msg "invalid-missing-role.gitmodules"           "'rca0'"       "names the failing submodule"
expect_msg "invalid-future-no-ancestor.gitmodules"     "rule-2"       "mentions rule-2"
expect_msg "invalid-future-no-ancestor.gitmodules"     "'sls'"        "names the failing submodule"
expect_msg "invalid-past-with-ancestor.gitmodules"     "rule-3"       "mentions rule-3"
expect_msg "invalid-url.gitmodules"                    "rule-4"       "mentions rule-4"
expect_msg "invalid-path-mismatch.gitmodules"          "rule-5"       "mentions rule-5"
expect_msg "invalid-duplicate-path.gitmodules"         "rule-6"       "mentions rule-6"
expect_msg "invalid-future-meta-ancestor.gitmodules"   "role 'meta'"  "names the wrong role"
expect_msg "invalid-future-future-ancestor.gitmodules" "role 'future'" "names the wrong role"

echo ""

# File-not-found → exit 2
set +e
sh "$VALIDATOR" "/nonexistent/path" >/dev/null 2>&1
_exit=$?
set -e
if [ "$_exit" -eq 2 ]; then
    echo "  PASS: exit 2 on missing file"
    pass=$((pass + 1))
else
    echo "  FAIL: exit 2 on missing file (got exit=$_exit)"
    fail=$((fail + 1))
fi

echo ""
echo "--- Results ---"
echo "$pass passed, $fail failed."

if [ "$fail" -gt 0 ]; then
    exit 1
fi
