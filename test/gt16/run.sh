#!/bin/sh
set -eu

PASS=0
FAIL=0
pass(){ PASS=$((PASS+1)); echo "  PASS: $1"; }
fail(){ FAIL=$((FAIL+1)); echo "  FAIL: $1" >&2; }

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

git -C "$REPO_ROOT" archive --format=tar HEAD | tar -x -C "$FIXTURE"
cd "$FIXTURE"
git init -q
git config user.email "gt16@test.com"
git config user.name "GT16"
git add -A
git commit -q -m "seed"

sh ./init.sh >/dev/null 2>&1 || { fail "init"; exit 1; }
sh ./bootstrap.sh >/dev/null 2>&1 || { fail "bootstrap"; exit 1; }

cat > meta/stance/vocabulary.toml <<'TOML'
[stance]
title = "GT16"
description = "Installer smoke"
floor = "floor"
claim = "claim"
experiment = "experiment"
blocked = "blocked"

[commands]
show = "show"
explore = "explore"
integrate = "integrate"
finish = "finish"
change_rules = "change-rules"
save = "save"
TOML

if sh .now/src/install-stance.sh >/tmp/gt16.install1.log 2>&1; then
  pass "install-stance happy path"
else
  fail "install-stance happy path"
fi

count=$(rg -n "stance:managed:begin" CLAUDE.md | wc -l | tr -d ' ')
[ "$count" = "1" ] && pass "single managed block after install" || fail "single managed block after install"

cat <<'BLOCK' >> CLAUDE.md

<!-- stance:managed:begin -->
@STANCE.md
<!-- stance:managed:end -->
BLOCK
if sh .now/src/install-stance.sh >/tmp/gt16.install2.log 2>&1; then
  count=$(rg -n "stance:managed:begin" CLAUDE.md | wc -l | tr -d ' ')
  [ "$count" = "1" ] && pass "rerun collapses duplicate managed blocks" || fail "rerun collapses duplicate managed blocks"
else
  fail "rerun with duplicate managed blocks"
fi

echo "bad" > .claude/commands/unexpected.md
if sh .now/src/install-stance.sh >/tmp/gt16.unexpected.log 2>&1; then
  fail "unexpected markdown should fail"
else
  pass "unexpected markdown fails install"
fi
rm -f .claude/commands/unexpected.md

echo '/tmp/evil.md' > .claude/commands/.stance-generated
if sh .now/src/install-stance.sh >/tmp/gt16.badindex.log 2>&1; then
  fail "invalid .stance-generated path should fail"
else
  pass "invalid .stance-generated path fails install"
fi

echo "\n=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
