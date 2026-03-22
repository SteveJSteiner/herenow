# Continuation — Single Current Task

## Protocol

- **Purpose:** the only active task for the current dispatch.
- **Authority:** current-task execution only.
- **Must contain:** one roadmap node ID, why now, dependencies, output files, local context, scope boundary, success condition, verification, stress test, audit target.
- **Must not contain:** multiple queued tasks, backlog items, roadmap-wide planning, long history.
- **Update rule:** after each commit, update this file to reflect the current active task state.
- **Update rule:** replace this file with the next single task only when the current task is completed or intentionally split.
- **Update rule:** if unfinished and still the same task, keep the same node ID and refresh only the local context/state as needed.

## Task Identity

- **Node ID:** GT10
- **Title:** Implement immune-response layer
- **Status:** READY

## Why now

GT9 is complete — D15 is closed with a hybrid auto-revert + tag-and-refuse-next mechanism, empirically validated across all three post-hook paths. The design is settled; GT10 implements it.

GT10 is on the critical path: GT10 → GT13 (end-to-end smoke). GT11 (meta self-consistency) is independently unblocked by GT8c and can proceed in parallel.

## Dependencies

- GT9 output: D15 closed in `decisions.md` §5.1 (hybrid auto-revert + tag-and-refuse-next)
- GT8c output: `.now/src/check-composition.sh` (the evaluator invoked for violation detection)
- Existing hook launchers in `.now/hooks/` (pre-commit, pre-merge-commit already exist from GT6)
- D15 per-hook behavior table (post-commit, post-merge, post-rewrite)
- D15 edge cases: amend coordination marker, rebase-in-progress detection, recursion guard, merge-commit `-m 1`

## Output Files

- `.now/hooks/post-commit` — immune-response handler for regular commits and amend
- `.now/hooks/post-merge` — immune-response handler for merges (fast-forward and true merge)
- `.now/hooks/post-rewrite` — immune-response handler for amend (coordination) and rebase (tag-and-refuse)
- `.now/src/immune-response.sh` (or equivalent) — shared response logic invoked by all three hooks
- Test script validating all hook paths
- `continuation.md` (refresh state while GT10 remains active)

## Local Context

- GT10 is a C node. The deliverable is working code with tests.
- The constraint evaluator (`check-composition.sh`) runs the full constraint suite. The immune-response hooks invoke it for detection, then execute the response per D15.
- Post-commit is the primary handler for normal commits and amend. It must detect rebase-in-progress (`.git/rebase-merge/` or `.git/rebase-apply/`) and defer.
- Post-merge handles fast-forward and `--no-ff` merges. Conflict-resolved merges are handled by post-commit (post-merge does not fire for them).
- Post-rewrite handles rebase (tag-and-refuse-next) and coordinates with post-commit for amend (check `MEMBRANE_VIOLATION_HANDLED` marker).
- All hooks share a recursion guard (`MEMBRANE_REVERTING` in git dir).
- `--no-verify` does NOT suppress post-hooks — this is the fundamental mechanism.
- `core.hooksPath` manipulation bypasses everything — out of scope for GT10 (GT11 addresses config-level tampering detection).

## Scope Boundary

In scope:
- implement post-commit, post-merge, post-rewrite hooks per D15
- shared response logic (detection, auto-revert, tag, recursion guard, coordination marker)
- test script covering: normal violation, amend violation, merge violation (ff and no-ff), rebase violation, recursion guard, clean commits pass through
- acceptance criteria validation

Out of scope:
- meta self-consistency (GT11)
- end-to-end smoke scenarios (GT13)
- resolving D18 (enforcement source location) or D19 (shell vs compiled)
- tag-and-refuse-next enforcement on subsequent governed operations (the tagging is in scope; the "refuse" gate check can be added to pre-commit in GT10 or deferred)

## Success Condition

- A `--no-verify` violation produces at most one bad commit before the system responds (GT10 acceptance).
- The response is visible and leaves a durable trace (GT10 acceptance).
- The repo does not silently continue in a violated state (GT10 acceptance).

## Stress Test

- Does a `--no-verify` commit get auto-reverted by post-commit?
- Does amend-with-violation get auto-reverted without double-revert (post-commit + post-rewrite coordination)?
- Does merge-with-violation get auto-reverted (both ff and no-ff)?
- Does rebase-with-violation get tagged (not auto-reverted)?
- Does the recursion guard prevent infinite revert loops?
- Do clean commits/merges/amends/rebases pass through without triggering the response?
- Does conflict-resolved merge get caught by post-commit?

## Audit Target

- post-commit, post-merge, post-rewrite hooks exist and are executable
- All three hook paths invoke the constraint evaluator for detection
- Auto-revert produces visible, auditable commits in `git log`
- Tag-and-refuse-next produces visible tags
- Recursion guard and coordination marker are cleaned up after use
- No silent violations persist

## Verification

- Test script exercises all hook paths with pass/fail assertions
- `--no-verify` violation is auto-reverted within one commit
- Amend violation is auto-reverted exactly once (no double-revert)
- Rebase violation is tagged
- Clean operations produce no response artifacts
