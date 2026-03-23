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

- **Node ID:** GT16
- **Title:** Hardening, split policy, and first-release cut
- **Status:** READY

## Why now

GT15 is complete — acceptance test validated the full template→init→bootstrap→governed path (25/25 assertions, both creation paths, D32 confirmed). All prior suites green (GT7–GT13, 137 total assertions). Every node GT0–GT15 is done. GT16 is the final node: convert the working prototype into a releasable template with explicit known limitations and a policy for future work.

## Dependencies

- GT15 output: acceptance test proving the full operator path works end-to-end
- GT0–GT14 outputs: complete spine — initializer, bootstrap, enforcement (past monotonicity, future grounding, atomic cross-check, meta consistency), immune response, worktree provisioning, template packaging, documentation

## Output Files

- `KNOWN-LIMITATIONS.md` or equivalent section in README — explicit list of current limitations and constraints
- `plan/decisions.md` update — split policy for future interstitial nodes
- Version tag criteria documented
- `continuation.md` (refresh state while GT16 remains active)

## Local Context

- GT16 is an H node. The deliverable is hardening and documentation, not new enforcement logic.
- The prototype is functionally complete: init→bootstrap→governed composition with enforcement, immune response, meta consistency, worktree provisioning.
- Total test coverage: 162 assertions across 7 test suites (GT7: 26, GT8a: 11, GT8b: 17, GT8c: 20, GT12: 34, GT13: 29, GT15: 25).
- The roadmap defines GT16 deliverables as: release notes/known limitations, documented split policy for oversized future nodes, version tag criteria.
- Acceptance: "The repo can be handed to another operator as a disciplined starter, not just a proof of concept."
- Current known gaps to document:
  - Enforcement files must be manually installed on `now` after init (init creates stubs; real hooks/src are on provenance/scaffold)
  - No CI integration (enforcement is local git hooks only)
  - No multi-remote or fork workflow support
  - Platform assumptions (POSIX shell, git 2.38+ for protocol.file.allow)
  - No `past`/`future` branch creation tooling (operator creates manually)

## Scope Boundary

In scope:
- Known limitations documented explicitly
- Split policy for future roadmap nodes (how to add interstitial nodes)
- Version tag criteria (what constitutes a release-worthy state)
- Any final hardening of documentation or error messages
- Release notes summarizing what GT0–GT15 produced

Out of scope:
- New enforcement logic or constraint changes
- Changes to init.sh, bootstrap.sh, or hook behavior
- CI/CD integration
- Multi-remote or fork workflow support
- Automated enforcement installation (that would be a future node)

## Success Condition

- The repo can be handed to another operator as a disciplined starter, not just a proof of concept.
- Known limitations are explicit — no hidden assumptions an operator would discover by surprise.
- A clear policy exists for adding future roadmap nodes without breaking the existing spine.
- Version tag criteria are documented so a release decision is mechanical, not subjective.

## Stress Test

- Would a new operator encountering the template know what works and what doesn't before running init.sh?
- Are the platform requirements (POSIX shell, git version) documented where the operator will see them?
- Does the split policy handle the case where a future node proves too large mid-implementation?
- Are the version tag criteria falsifiable (can you definitively say "this is/isn't release-ready")?

## Audit Target

- Known limitations documented and reachable from README or project root
- Split policy added to decisions.md or roadmap.md
- Version tag criteria documented
- Release notes summarize GT0–GT15 outputs
- All existing tests still pass after any documentation changes
- No new enforcement logic introduced (H node constraint)

## Verification

- All test suites still pass (GT7–GT13, GT15)
- Known limitations match actual observed behavior (no aspirational claims)
- Split policy is concrete enough to follow mechanically
- Version tag criteria are falsifiable
