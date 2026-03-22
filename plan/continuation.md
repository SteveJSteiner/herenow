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

- **Node ID:** GT8c
- **Title:** Constraint engine v1: atomic cross-check pass
- **Status:** READY

## Why now

GT8a and GT8b are both complete — the two prerequisite constraint checkers exist and pass their test suites:
- `.now/src/check-past-monotonicity.sh` — 11 tests (monotonic past advancement)
- `.now/src/check-future-grounding.sh` — 17 tests (future ancestry against named past)

GT8c combines these into an all-or-nothing evaluator that checks the full resulting configuration atomically, including future retirement/removal semantics. GT8c unblocks GT9 (immune-response design) and GT11 (meta self-consistency).

## Dependencies

- GT8a output: `.now/src/check-past-monotonicity.sh` (past monotonicity check)
- GT8b output: `.now/src/check-future-grounding.sh` (future grounding check)
- GT7 output: `.now/src/validate-gitmodules.sh` (static schema validation — run first)
- `decisions.md` §4.3 (D11: atomic consistency — full configuration, not individual pin updates)
- `decisions.md` §4.3 (cross-constraints: advancing past may invalidate futures, requiring simultaneous re-grounding)
- `roadmap.md` GT8c acceptance criteria

## Output Files

- Atomic cross-check evaluator (likely `.now/src/check-composition.sh`)
- Fixture repos in `test/gt8c/run.sh` (cross-constraint scenarios with real git history)
- `continuation.md` (refresh state while GT8c remains active)

## Local Context

- GT8c is a C (capability) node. The deliverable is working code, not design.
- The evaluator runs the full constraint suite against the candidate composition: schema validation (GT7), past monotonicity (GT8a), future grounding (GT8b).
- D11: the checker evaluates the full configuration atomically. A commit that advances a past pin while breaking a future's grounding must be rejected as a whole.
- Future retirement: removing a future submodule from the composition (deleting its `.gitmodules` entry and index gitlink) should not cause the remaining checks to fail. The retired future simply drops out of scope.
- Cross-constraint interaction: advancing a past may require simultaneously updating futures that depend on it. The evaluator must catch the case where past advances but a dependent future's fork point is no longer on the past's current line.
- Both GT8a and GT8b read from the index. The atomic evaluator can call them sequentially — if any fails, the composition is rejected.
- D18 (enforcement location) and D19 (shell vs. compiled) remain open. Continue in POSIX shell.

## Scope Boundary

In scope:
- compose GT7 + GT8a + GT8b into a single pass/fail evaluator
- verify cross-constraint invalidation (past advance breaks future grounding)
- verify future retirement (removing a future doesn't break remaining checks)
- atomic: any single check failure rejects the entire composition
- clear error output identifying which check(s) failed

Out of scope:
- hook integration (wiring into pre-commit)
- immune response (GT9)
- meta self-consistency (GT11)
- resolving D18 or D19

## Success Condition

- Cross-constraint invalidation is tested rather than assumed (GT8c acceptance).
- Removing a future from the resulting composition retires it cleanly from subsequent checks (GT8c acceptance).

## Stress Test

- Does it reject a commit that advances past while breaking a future's grounding?
- Does it accept a commit that advances past and simultaneously re-grounds the future?
- Does it handle removing a future submodule cleanly (retirement)?
- Does it reject when schema validation fails but individual checks would pass?
- Does it report all violations, not just the first?
- Does it pass when all constraints are satisfied simultaneously?

## Audit Target

- Evaluator calls GT7, GT8a, GT8b checks in sequence
- Cross-constraint failure (past advance + stale future) produces a rejection
- Future retirement does not produce false positives
- Error output is actionable: identifies which check failed and why

## Verification

- Run evaluator against composition where past advances and future is re-grounded → exit 0
- Run evaluator against composition where past advances but future is stale → exit non-zero
- Run evaluator against composition with a retired future → exit 0
- Run evaluator against composition with schema violation → exit non-zero
- Run evaluator against clean composition (all constraints met) → exit 0
