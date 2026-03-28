#!/bin/sh
set -eu

PASS=0
FAIL=0

pass() {
    PASS=$((PASS + 1))
    echo "  PASS: $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  FAIL: $1" >&2
}

assert_contains() {
    _label="$1"
    _haystack="$2"
    _needle="$3"
    case "$_haystack" in
        *"$_needle"*) pass "$_label" ;;
        *) fail "$_label (missing '$_needle')" ;;
    esac
}

assert_not_contains() {
    _label="$1"
    _haystack="$2"
    _needle="$3"
    case "$_haystack" in
        *"$_needle"*) fail "$_label (unexpected '$_needle')" ;;
        *) pass "$_label" ;;
    esac
}

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

git -C "$REPO_ROOT" archive --format=tar HEAD | tar -x -C "$FIXTURE"
cd "$FIXTURE"

git init -q
git config user.email "gt-extra@test.com"
git config user.name "GT Extra"
git config commit.gpgsign false
git add -A
git commit -q -m "seed"

init_log="$FIXTURE/init.log"
sh ./init.sh >"$init_log" 2>&1 || { fail "init.sh failed"; cat "$init_log"; exit 1; }
bootstrap_log="$FIXTURE/bootstrap.log"
sh ./bootstrap.sh >"$bootstrap_log" 2>&1 || { fail "bootstrap.sh failed"; cat "$bootstrap_log"; exit 1; }
update1_log="$FIXTURE/gt-extra.update1.log"
update2_log="$FIXTURE/gt-extra.update2.log"
update4_log="$FIXTURE/gt-extra.update4.log"
update6_log="$FIXTURE/gt-extra.update6.log"

manifest_on_meta() {
    meta_tip=$(git rev-parse refs/heads/meta)
    git show "$meta_tip:enforcement-manifest"
}

write_extra_manifest_file() {
    _content="$1"
    _wt="$FIXTURE/wt-meta"
    rm -rf "$_wt"
    git worktree add -q "$_wt" meta
    printf '%s\n' "$_content" > "$_wt/extra-manifested-files"
    git -C "$_wt" add extra-manifested-files
    git -C "$_wt" commit -q -m "Update extra-manifested-files"
    git worktree remove -f "$_wt"
}

# ---------------------------------------------------------------------------
# Test 1: Backward compatibility
# ---------------------------------------------------------------------------
echo "--- Test 1: Backward compatibility"
printf 'canary-content\n' > canary.txt
sh .now/src/update-manifest.sh >"$update1_log" 2>&1 || {
    fail "update-manifest succeeds without extra-manifested-files"
    echo "--- output ---"
    cat "$update1_log"
    echo "-------------"
    exit 1
}
manifest="$(manifest_on_meta)"
assert_not_contains "canary.txt absent from manifest by default" "$manifest" "canary.txt"

git commit -q -m "test1 governed commit" --allow-empty && pass "governed commit succeeds without extra-manifested-files" || fail "governed commit succeeds without extra-manifested-files"

# ---------------------------------------------------------------------------
# Test 2: Seal an extra file
# ---------------------------------------------------------------------------
echo "--- Test 2: Seal an extra file"
write_extra_manifest_file "CLAUDE.md"

printf 'sealed content\n' > CLAUDE.md
sh .now/src/update-manifest.sh >"$update2_log" 2>&1 || {
    fail "update-manifest succeeds with declared extra file"
    cat "$update2_log"
    exit 1
}
manifest="$(manifest_on_meta)"
assert_contains "manifest contains CLAUDE.md entry" "$manifest" " CLAUDE.md"

expected_hash=$(git hash-object CLAUDE.md)
manifest_hash=$(printf '%s\n' "$manifest" | awk '$2=="CLAUDE.md"{print $1}')
if [ "$manifest_hash" = "$expected_hash" ]; then
    pass "CLAUDE.md hash matches manifest"
else
    fail "CLAUDE.md hash matches manifest (expected $expected_hash got ${manifest_hash:-<none>})"
fi

git commit -q -m "test2 governed commit" && pass "governed commit succeeds with sealed extra file" || fail "governed commit succeeds with sealed extra file"
head_hash=$(git rev-parse HEAD:CLAUDE.md)
if [ "$head_hash" = "$expected_hash" ]; then
    pass "governed commit includes staged CLAUDE.md content"
else
    fail "governed commit includes staged CLAUDE.md content"
fi

# ---------------------------------------------------------------------------
# Test 3: Tamper detection
# ---------------------------------------------------------------------------
echo "--- Test 3: Tamper detection"
printf 'tampered content\n' > CLAUDE.md
git add CLAUDE.md
set +e
commit_output=$(git commit -m "test3 tamper should fail" 2>&1)
commit_rc=$?
set -e
if [ "$commit_rc" -ne 0 ]; then
    pass "tampered commit rejected"
else
    fail "tampered commit rejected"
fi
assert_contains "tamper stderr mentions CLAUDE.md" "$commit_output" "CLAUDE.md"
assert_contains "tamper stderr mentions mismatch" "$commit_output" "mismatch"

git reset -q HEAD CLAUDE.md
git checkout -q -- CLAUDE.md

# ---------------------------------------------------------------------------
# Test 4: Regeneration preserves seal
# ---------------------------------------------------------------------------
echo "--- Test 4: Regeneration preserves seal"
pre_hash=$(printf '%s\n' "$(manifest_on_meta)" | awk '$2=="CLAUDE.md"{print $1}')
printf '\n# GT extra test marker\n' >> .now/src/update-manifest.sh
sh .now/src/update-manifest.sh >"$update4_log" 2>&1 || {
    fail "update-manifest succeeds after enforcement source change"
    cat "$update4_log"
    exit 1
}
manifest="$(manifest_on_meta)"
assert_contains "regenerated manifest still contains CLAUDE.md" "$manifest" " CLAUDE.md"
post_hash=$(printf '%s\n' "$manifest" | awk '$2=="CLAUDE.md"{print $1}')
if [ "$pre_hash" = "$post_hash" ]; then
    pass "CLAUDE.md hash unchanged after regeneration"
else
    fail "CLAUDE.md hash unchanged after regeneration"
fi
git commit -q -m "test4 governed commit" && pass "governed commit succeeds after regeneration" || fail "governed commit succeeds after regeneration"

# ---------------------------------------------------------------------------
# Test 5: Missing declared file
# ---------------------------------------------------------------------------
echo "--- Test 5: Missing declared file"
rm -f CLAUDE.md
set +e
missing_output=$(sh .now/src/update-manifest.sh 2>&1)
missing_rc=$?
set -e
if [ "$missing_rc" -ne 0 ]; then
    pass "update-manifest exits non-zero when declared file missing"
else
    fail "update-manifest exits non-zero when declared file missing"
fi
assert_contains "missing-file error names CLAUDE.md" "$missing_output" "CLAUDE.md"

git checkout -q -- CLAUDE.md

# ---------------------------------------------------------------------------
# Test 6: Comment and blank line handling
# ---------------------------------------------------------------------------
echo "--- Test 6: Comments and blanks"
write_extra_manifest_file "# This is a comment
CLAUDE.md
CLAUDE.md

# Another comment"

sh .now/src/update-manifest.sh >"$update6_log" 2>&1 || {
    fail "update-manifest succeeds with comments/blanks in extra-manifested-files"
    cat "$update6_log"
    exit 1
}
manifest="$(manifest_on_meta)"
extra_count=$(printf '%s\n' "$manifest" | awk '$2=="CLAUDE.md"{c++} END{print c+0}')
if [ "$extra_count" -eq 1 ]; then
    pass "exactly one CLAUDE.md extra entry"
else
    fail "exactly one CLAUDE.md extra entry (got $extra_count)"
fi
assert_not_contains "no comment entries manifested" "$manifest" "# This is a comment"
blank_or_comment_entries=$(printf '%s\n' "$manifest" | awk 'NF>=2 && ($2 ~ /^#/ || $2 == ""){c++} END{print c+0}')
if [ "$blank_or_comment_entries" -eq 0 ]; then
    pass "no blank/comment pseudo-path entries manifested"
else
    fail "no blank/comment pseudo-path entries manifested"
fi

# ---------------------------------------------------------------------------
# Test 7: Reject unsafe paths
# ---------------------------------------------------------------------------
echo "--- Test 7: Reject unsafe paths"
write_extra_manifest_file "../outside.txt"
set +e
unsafe_output=$(sh .now/src/update-manifest.sh 2>&1)
unsafe_rc=$?
set -e
if [ "$unsafe_rc" -ne 0 ]; then
    pass "update-manifest rejects unsafe ../ paths"
else
    fail "update-manifest rejects unsafe ../ paths"
fi
assert_contains "unsafe path error mentions rejected path" "$unsafe_output" "../outside.txt"

write_extra_manifest_file "/tmp/abs.txt"
set +e
unsafe_abs_output=$(sh .now/src/update-manifest.sh 2>&1)
unsafe_abs_rc=$?
set -e
if [ "$unsafe_abs_rc" -ne 0 ]; then
    pass "update-manifest rejects unsafe absolute paths"
else
    fail "update-manifest rejects unsafe absolute paths"
fi
assert_contains "unsafe absolute path error mentions rejected path" "$unsafe_abs_output" "/tmp/abs.txt"

write_extra_manifest_file "bad path.txt"
set +e
unsafe_ws_output=$(sh .now/src/update-manifest.sh 2>&1)
unsafe_ws_rc=$?
set -e
if [ "$unsafe_ws_rc" -ne 0 ]; then
    pass "update-manifest rejects whitespace in paths"
else
    fail "update-manifest rejects whitespace in paths"
fi
assert_contains "unsafe whitespace path error mentions rejected path" "$unsafe_ws_output" "bad path.txt"

printf 'symlink target\n' > linked-target.txt
ln -sf linked-target.txt linked-file
write_extra_manifest_file "linked-file"
set +e
unsafe_link_output=$(sh .now/src/update-manifest.sh 2>&1)
unsafe_link_rc=$?
set -e
if [ "$unsafe_link_rc" -ne 0 ]; then
    pass "update-manifest rejects symlink entries"
else
    fail "update-manifest rejects symlink entries"
fi
assert_contains "unsafe symlink error mentions rejected path" "$unsafe_link_output" "linked-file"

mkdir -p realdir
printf 'parent symlink target\n' > realdir/inner.txt
ln -sfn realdir linked-dir
write_extra_manifest_file "linked-dir/inner.txt"
set +e
unsafe_parent_link_output=$(sh .now/src/update-manifest.sh 2>&1)
unsafe_parent_link_rc=$?
set -e
if [ "$unsafe_parent_link_rc" -ne 0 ]; then
    pass "update-manifest rejects paths containing parent symlink components"
else
    fail "update-manifest rejects paths containing parent symlink components"
fi
assert_contains "unsafe parent symlink error mentions rejected path" "$unsafe_parent_link_output" "linked-dir/inner.txt"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
