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

- **Node ID:** GT8b
- **Title:** Constraint engine v1: grounded futures
- **Status:** READY

## Why now

GT8a is complete — `.now/src/check-past-monotonicity.sh` implements the monotonic-past check, passing all 11 tests (valid advancement, newly added, non-past ignored, backward/sideways rejection, mixed multi-submodule, error message content). GT8b is now unblocked. GT8b shares infrastructure patterns with GT8a (submodule name parsing, gitlink extraction from index) and is the other prerequisite for GT8c (atomic cross-check pass).

## Dependencies

- GT7 output: `.now/src/validate-gitmodules.sh` (role and ancestor-constraint lookup)
- GT8a output: `.now/src/check-past-monotonicity.sh` (structural pattern reference — same parsing, same gitlink extraction)
- `decisions.md` §4.2 (D9: futures must be grounded in a named past — `git merge-base` fork-point check)
- `decisions.md` §4.2 (D10: fork point need not be current past tip — "descended from somewhere on past's line")
- `decisions.md` §4.3 (D11: atomic consistency — checker evaluates the full resulting configuration)
- `roadmap.md` GT8b acceptance criteria

## Output Files

- Grounded-future check implementation (likely `.now/src/check-future-grounding.sh`)
- Fixture repos in `test/gt8b/run.sh` (real git history with submodule pins)
- `continuation.md` (refresh state while GT8b remains active)

## Local Context

- GT8b is a C (capability) node. The deliverable is working code, not design.
- The check verifies each future-typed submodule's pin descends from its declared past's lineage.
- For each future submodule: get future-pin and past-pin from the index (the candidate composition), find `git merge-base <future-pin> <past-pin>`, verify the fork point is non-trivial (not a root commit).
- D10: the fork point need not be the current past tip. A future started from an earlier past state is still valid. The constraint is "descended from somewhere on past's line."
- Both future-pin and past-pin are read from the index (candidate state), not HEAD. The check evaluates the resulting composition, not the delta.
- `ancestor-constraint` key in `.gitmodules` names the past submodule each future must descend from.
- D18 (enforcement location) and D19 (shell vs. compiled) remain open. Continue in POSIX shell.

## Scope Boundary

In scope:
- verify each future submodule's pin descends from its ancestor-constraint past's lineage
- read both future-pin and past-pin from the index (candidate composition)
- accept: fork point exists and is not a root commit
- reject: no common ancestor, or fork point is a root commit (trivial shared history)
- produce clear error messages identifying which future submodule, its ancestor-constraint, and the pins
- run against fixture repos with real git history

Out of scope:
- past monotonicity checks (GT8a — already done)
- cross-constraint atomicity (GT8c — combining GT8a + GT8b)
- hook integration (wiring into pre-commit)
- resolving D18 or D19

## Success Condition

- Fixture repos cover valid and invalid grounding (GT8b acceptance).
- Grounding checks are evaluated from the candidate resulting composition (GT8b acceptance).

## Stress Test

- Does it handle a future forked from an early past commit (not the tip)?
- Does it handle a future forked from the current past tip?
- Does it handle a future with no shared history with its past (completely unrelated)?
- Does it handle a future whose only shared ancestor is the root commit?
- Does it handle multiple futures grounded in different pasts?
- Does it handle a future whose past submodule has no pin in the index?

## Audit Target

- Grounding check produces correct accept/reject on fixture repos
- Error messages identify the failing future, its ancestor-constraint, and the relevant SHAs
- The check uses `git merge-base` as specified in §4.2
- Both pins are read from the index (candidate composition), not HEAD

## Verification

- Run check against fixture repo with future forked from past lineage → exit 0
- Run check against fixture repo with future forked from past tip → exit 0
- Run check against fixture repo with unrelated future → exit non-zero, error message names the violation
- Run check against fixture repo with root-only shared ancestor → exit non-zero
- Run check against fixture repo with multiple valid futures → exit 0
