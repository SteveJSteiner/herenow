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

- **Node ID:** GT8a
- **Title:** Constraint engine v1: past monotonicity
- **Status:** READY

## Why now

GT7 is complete — the `.gitmodules` parser/validator exists at `.now/src/validate-gitmodules.sh`, passing all 26 tests (6 static schema rules, error message checks, edge cases). GT8a and GT8b are both unblocked. GT8a is taken first because the monotonic-past check is simpler (single `git merge-base --is-ancestor` call) and GT8b (grounded futures) will reuse the same check infrastructure.

## Dependencies

- GT7 output: `.now/src/validate-gitmodules.sh` (parser for role descriptors from `.gitmodules`)
- `decisions.md` §4.1 (D8: past pins advance monotonically — `git merge-base --is-ancestor <old-pin> <new-pin>`)
- `decisions.md` §4.3 (D11: atomic consistency at commit time — the checker evaluates the full resulting configuration)
- `roadmap.md` GT8a acceptance criteria

## Output Files

- Monotonic-past check implementation (likely `.now/src/check-past-monotonicity.sh` or integrated into a constraint engine entry point)
- Fixture repos (not fixture files — these checks need actual git history with submodule pins)
- `continuation.md` (refresh state while GT8a remains active)

## Local Context

- GT8a is a C (capability) node. The deliverable is working code, not design.
- The check compares old-pin vs new-pin for each past-typed submodule: `git merge-base --is-ancestor <old-pin> <new-pin>`.
- "Old pin" = the past submodule's gitlink SHA in HEAD (the pre-change state).
- "New pin" = the past submodule's gitlink SHA in the staged index (the candidate state).
- The validator from GT7 provides the role lookup: which submodules are `past`-typed.
- D18 (enforcement location) and D19 (shell vs. compiled) remain open. Continue in POSIX shell.
- This check will eventually be called from a pre-commit hook, but hook wiring is not GT8a's scope.

## Scope Boundary

In scope:
- detect when a past submodule pin moves backward or sideways (non-descendant)
- compare HEAD gitlink vs index gitlink for each past-typed submodule
- accept: new pin is descendant of old pin, or submodule is newly added (no old pin)
- reject: new pin is not a descendant of old pin
- produce clear error messages identifying which past submodule and the old/new SHAs
- run against a fixture repo with real git history

Out of scope:
- grounded-future checks (GT8b)
- cross-constraint atomicity (GT8c)
- hook integration (wiring into pre-commit)
- resolving D18 or D19

## Success Condition

- Fixture repos cover accepted and rejected past-pin transitions (GT8a acceptance).
- Violating past-pin changes are detected (GT8a acceptance — "rejected before commit" deferred to hook wiring).

## Stress Test

- Does it handle a past submodule being added for the first time (no old pin)?
- Does it handle a past pin advancing to a direct descendant (should accept)?
- Does it handle a past pin moving to a sibling branch (should reject)?
- Does it handle a past pin moving backward (should reject)?
- Does it handle multiple past submodules where one advances validly and one regresses?

## Audit Target

- Monotonic check produces correct accept/reject on fixture repos
- Error messages identify the failing submodule and the old/new SHAs
- The check uses `git merge-base --is-ancestor` as specified in §4.1

## Verification

- Run check against fixture repo with valid past advancement → exit 0, no errors
- Run check against fixture repo with backward past pin → exit non-zero, error message names the violation
- Run check against fixture repo with sideways past pin → exit non-zero
- Run check against fixture repo with newly added past (no old pin) → exit 0
