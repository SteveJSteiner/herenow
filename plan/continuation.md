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

- **Node ID:** GT11
- **Title:** Meta self-consistency mechanism
- **Status:** READY

## Why now

GT10 is complete — the immune-response layer is implemented and tested across all hook paths. GT11 is unblocked by GT8c and is on the critical path to GT13 (end-to-end smoke), which requires GT10 + GT11 + GT12.

GT11 closes D12 (OPEN — mechanism for meta self-consistency verification). The decision text says this "needs practical testing" — GT11 is that practical testing. The current enforcement source lives on `now` in `.now/src/` and `.now/hooks/`. The meta submodule is declared in `.gitmodules`. GT11 must determine what "active enforcement matches declared meta state" means concretely and implement the first check.

GT12 (worktree provisioning) is independently unblocked by GT3 and can proceed in parallel.

## Dependencies

- GT8c output: `.now/src/check-composition.sh` (the evaluator — GT11 adds a meta-consistency check to this suite or alongside it)
- D12 (OPEN): self-consistency between active machinery and declared meta is a requirement; mechanism not yet decided
- D18 (OPEN): whether enforcement source lives on now or in meta — affects what "declared meta state" means
- Current enforcement source: `.now/src/*.sh`, `.now/hooks/*` — all on the `now` branch
- Meta submodule: declared in `.gitmodules` with `role = meta`, pinned to a SHA on the `meta` branch
- GT3 output: `init.sh` creates the `meta` branch with initial content

## Output Files

- `.now/src/check-meta-consistency.sh` (or equivalent) — the self-consistency checker
- Update to `.now/src/check-composition.sh` if meta-consistency is added to the constraint suite
- Decision closure for D12 in `decisions.md`
- Test script validating consistency detection
- `continuation.md` (refresh state while GT11 remains active)

## Local Context

- GT11 is a C node. The deliverable is working code with tests.
- D12 is OPEN with two candidate mechanisms: byte-identity of files, or hash of source tree. The concern is that byte-identity is too rigid (line endings, formatting) while hash comparison is too opaque.
- D18 is OPEN: enforcement source on now vs. meta. Currently the source IS on now. GT11 should work with the current reality (source on now) while keeping the design compatible with either D18 outcome.
- The meta submodule pin on `now` points to a SHA on the `meta` branch. The `meta` branch was created by `init.sh` (GT3). Its content represents the declared operational state.
- The check needs to answer: "does the active enforcement machinery match what the meta pin says it should be?"
- If source is on now: the meta pin might declare which version of enforcement is expected, and the check compares active files against that declaration.
- If source is in meta: the meta pin points to the tree containing the enforcement source, and the check compares active files against the tree at that pin.
- Platform concern: line endings, executable bits, and filesystem metadata can differ across platforms. The mechanism must handle this or document exact assumptions.

## Scope Boundary

In scope:
- Close D12 with a concrete mechanism, informed by practical testing
- Implement the self-consistency checker
- Test with controlled mismatch scenarios
- Handle or document platform variation (line endings, exec bits)
- Integrate with the constraint suite if appropriate

Out of scope:
- Closing D18 (enforcement source location) — GT11 works with current reality
- Closing D19 (source language) — GT11 uses shell, consistent with current codebase
- Worktree provisioning (GT12)
- End-to-end smoke scenarios (GT13)

## Success Condition

- A controlled mismatch between active enforcement and declared meta state is detectable (GT11 acceptance).
- The mechanism is stable across normal line-ending/platform variation or else documents exact platform assumptions (GT11 acceptance).

## Stress Test

- Does a modified hook file get detected as inconsistent?
- Does a modified enforcement source file get detected as inconsistent?
- Does a clean state (no modifications) pass the consistency check?
- Does advancing the meta pin to a new SHA with matching content pass?
- Does advancing the meta pin to a new SHA with different content fail?
- Are line-ending differences handled (or explicitly documented as a known limitation)?
- Does the check work when the meta submodule is not initialized (reading from git objects directly)?

## Audit Target

- Self-consistency checker exists and is executable
- Controlled mismatch produces a clear violation report
- Clean state produces no false positives
- D12 is closed in `decisions.md` with recorded mechanism and rationale
- Platform assumptions are documented if not fully handled

## Verification

- Test script exercises match and mismatch scenarios with pass/fail assertions
- Mismatch is detected without false positives on clean state
- D12 closure is recorded in `decisions.md`
