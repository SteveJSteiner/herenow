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

- **Node ID:** GT15
- **Title:** Fresh-repo acceptance from GitHub template to governed membrane
- **Status:** READY

## Why now

GT14 is complete — README.md written with pre-init→post-init quick start, D32 verified (GitHub template copies only default branch contents; no membrane branches or refs in generated repos). Both GT15 dependencies are met: GT13 (end-to-end smoke test, 29/29 assertions, all suites green) and GT14 (template packaging). GT15 is the acceptance node that validates the full operator path from template generation to governed operation.

## Dependencies

- GT13 output: proven spine (smoke test, pre-commit hooks, all component tests — 133 total)
- GT14 output: README.md with quick-start instructions, D32 verification

## Output Files

- `test/gt15/run.sh` — acceptance script exercising the full template→init→bootstrap→governed path
- `continuation.md` (refresh state while GT15 remains active)

## Local Context

- GT15 is an H node. The deliverable is acceptance validation, not new enforcement logic.
- The acceptance script must simulate what a new operator experiences: start from a fresh repo containing only the main-branch contents (as GitHub's "Use this template" would produce), then follow the documented steps.
- The script should create a temporary bare clone of just the main branch (simulating template generation), then run init.sh → bootstrap.sh and verify the governed state.
- D32 must be validated in two paths: default-branch-only creation AND "Include all branches" (both must result in no membrane refs before init).
- The acceptance script should verify the README's documented commands actually work in sequence.
- Existing test infrastructure: `test/gt13/smoke.sh` (29 assertions), `test/gt12/run.sh` (34 assertions), `test/gt7/run.sh`, `test/gt8a/run.sh`, `test/gt8b/run.sh`, `test/gt8c/run.sh`.
- The acceptance test differs from GT13's smoke test: GT13 tests the spine in-place; GT15 tests from a fresh starting point as an operator would encounter it.

## Scope Boundary

In scope:
- Acceptance script that simulates template generation → init → bootstrap → governed state
- D32 validation: no membrane branches or refs before init (both creation paths)
- Verify documented steps from README actually produce a governed now branch
- Concrete assertions (not prose claims)

Out of scope:
- New enforcement logic or constraint changes
- Changes to init.sh or bootstrap.sh
- Hardening or release notes (GT16)
- Actually publishing to GitHub (acceptance is local simulation)

## Success Condition

- Starting from a simulated template-generated repo, the operator can reach a governed `now` branch with working constraints by following the documented steps.
- The acceptance script records concrete checks instead of prose claims.
- Before `./init.sh` runs, the generated repo contains no membrane branches and no `refs/membrane/root`.

## Stress Test

- Does the simulated template generation accurately reflect what GitHub's "Use this template" produces?
- Does init.sh work correctly in a repo that has no membrane refs at all?
- Does bootstrap.sh succeed in the freshly initialized repo?
- After bootstrap, do composition constraints actually fire on commits to now?
- Does "Include all branches" path also produce a clean pre-init state?

## Audit Target

- `test/gt15/run.sh` exists and is executable
- Script simulates template generation (fresh repo with only main-branch contents)
- Pre-init state verified: no membrane branches, no refs/membrane/root
- init.sh runs successfully in the fresh repo
- bootstrap.sh runs successfully after init
- At least one governance check fires after bootstrap (constraint enforcement is live)
- Both template creation paths validated (default-branch-only and all-branches)
- All assertions are concrete (exit codes, ref checks, hook behavior)

## Verification

- `test/gt15/run.sh` exits 0 with all assertions passing
- Existing test suites still pass (GT7–GT13)
- Acceptance covers the exact sequence documented in README.md
