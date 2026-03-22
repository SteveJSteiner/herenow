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

- **Node ID:** GT9
- **Title:** Immune-response design closure
- **Status:** READY

## Why now

GT8c is complete — the atomic cross-check evaluator (`.now/src/check-composition.sh`) composes GT7 + GT8a + GT8b into a single pass/fail gate, with 20 tests covering cross-constraint invalidation, future retirement, full error reporting, and schema-only rejection. The constraint engine v1 is done.

GT9 is a Q (design question) node that decides what happens when a violation is detected *after* commit — the non-bypassable immune-response layer. D14 established two-layer enforcement (gate + detection), but D15 (what the response *does*) is still open. GT9 closes D15.

GT9 is on the critical path: GT9 → GT10 (implement immune response) → GT13 (end-to-end smoke).

## Dependencies

- GT8c output: `.now/src/check-composition.sh` (the evaluator the immune response will invoke for detection)
- `decisions.md` §5.1 (D14: two-layer enforcement — closed; D15: immune response behavior — open)
- `decisions.md` §5.1 candidate mechanisms: auto-revert, tag-and-refuse-next, tag-and-degrade
- `decisions.md` §6 risk: "Post-hook revert mechanics … Whether auto-revert inside a post-hook is reliable across git versions, merge types, and edge cases is untested."
- `roadmap.md` GT9 acceptance criteria

## Output Files

- `decisions.md` update: close D15 with chosen mechanism and recorded reasons
- `decisions.md` update: capture mechanical edge cases discovered during testing
- `continuation.md` (refresh state while GT9 remains active)

## Local Context

- GT9 is a Q node. The deliverable is a design decision, not code. But the acceptance criteria require that "mechanical edge cases discovered during testing are captured" — so empirical testing of the candidate mechanisms is expected, not just reasoning.
- D14 established that `post-commit`, `post-merge`, and `post-rewrite` are the non-bypassable hooks. The immune response fires from these paths.
- Current leaning per decisions.md: auto-revert if mechanically sound.
- Key concern: can a post-commit hook reliably create a revert commit? Does this work across git versions, merge commits, and rewrite scenarios (amend, rebase)?
- Alternative if auto-revert is unsound: tag-and-refuse-next (tag the violation, next governed operation checks parent and refuses). Weaker but simpler.
- The constraint evaluator (`check-composition.sh`) already exists and can be called from post-hooks for detection. GT9 decides what happens *after* detection.
- Rewrite-sensitive paths (`post-rewrite`) are explicitly required by GT9 acceptance: "Rewrite-sensitive hook paths are explicitly covered."

## Scope Boundary

In scope:
- empirically test auto-revert from post-commit hook (mechanically sound?)
- empirically test auto-revert from post-merge hook
- empirically test detection/response from post-rewrite hook (amend, rebase)
- choose one mechanism with recorded reasons
- capture discovered edge cases in decisions.md
- explicitly cover rewrite-sensitive hook paths

Out of scope:
- implementing the full immune-response layer (GT10)
- meta self-consistency (GT11)
- resolving D18 (enforcement source location) or D19 (shell vs compiled)

## Success Condition

- One mechanism is chosen with recorded reasons (GT9 acceptance).
- Mechanical edge cases discovered during testing are captured in the design (GT9 acceptance).
- Rewrite-sensitive hook paths are explicitly covered (GT9 acceptance).

## Stress Test

- Does auto-revert from post-commit produce a clean revert commit?
- Does auto-revert from post-merge work (merge commits have multiple parents)?
- Does post-rewrite fire after `git commit --amend`? After `git rebase`?
- Can a determined operator chain bypasses faster than the response? What is the exposure window?
- What happens if the revert itself triggers the post-commit hook recursively?
- Is the chosen mechanism visible and auditable in `git log`?

## Audit Target

- D15 is closed with a concrete mechanism choice
- Edge cases from empirical testing are recorded in decisions.md
- post-commit, post-merge, and post-rewrite are all covered
- Recursion/re-entrancy is addressed (response hook doesn't infinite-loop)

## Verification

- D15 status changes from OPEN to CLOSED in decisions.md
- The chosen mechanism's behavior is described for all three hook paths
- At least one edge case from empirical testing is documented
- The decisions.md risk entry for "Post-hook revert mechanics" is updated with findings
