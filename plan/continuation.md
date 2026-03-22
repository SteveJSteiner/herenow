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

- **Node ID:** GT13
- **Title:** End-to-end fixture repo and smoke scenarios
- **Status:** READY

## Why now

GT12 is complete — worktree provisioner implemented and tested (34/34 assertions). All three GT13 dependencies are met: GT10 (immune response), GT11 (meta self-consistency), GT12 (worktree provisioning). GT13 is the integration gate: it proves the full spine works end-to-end before packaging (GT14) and fresh-repo acceptance (GT15).

## Dependencies

- GT3 output: `init.sh` creates membrane topology
- GT6 output: `bootstrap.sh` activates governed environment
- GT7/GT8a/GT8b/GT8c output: constraint engine (`.now/src/check-composition.sh` and siblings)
- GT10 output: immune-response hooks (`.now/hooks/post-commit`, `post-merge`, `post-rewrite`) + shared logic (`immune-response.sh`)
- GT11 output: meta self-consistency (`check-meta-consistency.sh`)
- GT12 output: worktree provisioner (`provision-worktrees.sh`)

## Output Files

- `test/gt13/smoke.sh` — single-command smoke test runner
- `.now/hooks/pre-commit` — bypassable governance check (wires check-composition.sh into pre-commit surface; needed for "invalid composition rejected" scenario)
- `.now/hooks/pre-merge-commit` — same for merge commits
- `continuation.md` (refresh state while GT13 remains active)

## Local Context

- GT13 is an H node. The deliverable is a reproducible demonstration that the full spine works.
- The smoke test must build a realistic fixture repo from scratch: init → install enforcement machinery → bootstrap → create temporal branches → exercise compositions.
- Pre-commit hooks don't exist yet (init.sh plants stubs; GT10 only implemented post-hooks). The smoke test needs pre-commit to demonstrate "invalid composition blocked" vs "bypass → immune response". Writing thin pre-commit/pre-merge-commit wrappers around check-composition.sh is in scope.
- The smoke test fixture must install enforcement scripts (`.now/src/*`) and real hooks onto the `now` branch, since init.sh only seeds stubs. This mirrors what the final template would ship.
- Existing component tests (GT7: 26, GT8a: 11, GT8b: 17, GT8c: 20, GT12: 34) test pieces in isolation. GT13 tests them composed and sequenced as a user would encounter them.

## Scope Boundary

In scope:
- Single-command smoke script exercising the full lifecycle
- Scenario coverage: init, bootstrap, valid composition, invalid composition (rejected), bypass + immune response, worktree provisioning
- Thin pre-commit and pre-merge-commit hooks (wrappers around check-composition.sh)

Out of scope:
- GitHub template packaging (GT14)
- Fresh-repo acceptance from template (GT15)
- New enforcement logic or constraint changes

## Smoke Scenarios

1. **Init + Bootstrap** — run init.sh, install enforcement machinery, run bootstrap.sh. Verify: hooks active, meta submodule initialized, constraint evaluator reachable.
2. **Valid composition** — create past branch (rca0) + future branch (sls) from membrane root, declare in .gitmodules, stage correct gitlinks, commit. Verify: commit succeeds, no immune response.
3. **Invalid composition (pre-commit block)** — attempt backward past pin. Verify: commit rejected at pre-commit.
4. **Bypass + immune response** — force invalid composition with `--no-verify`. Verify: commit lands, post-commit auto-reverts, revert commit present in log.
5. **Worktree provisioning** — run provision-worktrees.sh. Verify: worktrees created for declared roles.
6. **Meta consistency** — verify check-meta-consistency.sh passes with correct meta pin (or demonstrate detection of deliberate mismatch).

## Success Condition

- One command (`sh test/gt13/smoke.sh`) runs all scenarios and reports pass/fail.
- Scenarios produce outputs suitable for regression testing and future agent use (GT13 acceptance).

## Stress Test

- Does the smoke test work on a completely fresh temp directory (no leftover state)?
- Does each scenario cleanly set up its own preconditions?
- Are failures reported with enough context to diagnose?
- Does the bypass scenario actually produce and then revert the violating commit?
- Does the smoke test clean up after itself (no temp dirs left)?

## Audit Target

- Smoke script exists and is executable
- All scenarios pass from a clean state
- Pre-commit hooks reject invalid composition
- Post-commit auto-reverts bypass violations
- Worktree provisioning works within the smoke fixture
- Existing component tests (GT7–GT12) still pass

## Verification

- `sh test/gt13/smoke.sh` exits 0 with all scenarios passing
- All existing test suites still pass after GT13 additions
