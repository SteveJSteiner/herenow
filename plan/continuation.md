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

- **Node ID:** GT2
- **Title:** Initializer UX and idempotence contract
- **Status:** ACTIVE

## Why now

GT1 is closed: the canonical initialized layout, branch naming (D24), initialized branch set (D25), provenance invariants (D26), now-branch skeleton (D3-LAYOUT closed), and planning-file placement (D27) are all settled. GT3 (topology creation) depends on both GT1 and GT2, so GT2 is now the sole blocker on the critical path to the first implementation node. Without a settled init entry point and recovery model, GT3 cannot implement without making hidden product decisions about command interface, failure modes, and re-runnability.

## Dependencies

- `requirements.md` (R17 bootstrapping, R19 template sovereignty)
- `decisions.md` (D22 single bootstrap entry point, D23 submodule init strategy still open, D25 initialized branch set)
- `roadmap.md` (GT2 node definition)
- GT1 outputs: canonical skeleton, branch naming, planning-file placement are now settled constraints that GT2 must respect

## Output Files

- `decisions.md` (init command contract, idempotence/recovery semantics, failure-mode decisions)
- `roadmap.md` (only if GT2 changes downstream chunk boundaries or dependencies)
- `continuation.md` (refresh state while GT2 remains active)

## Local Context

- The roadmap already lists GT2's questions to resolve:
  - `./init.sh`, `just init`, `cargo run -p ...`, or other entry point?
  - May init rewrite local history?
  - What happens if init partially succeeds?
  - Is re-running init supported?
- D22 commits to a single bootstrap entry point with recovery semantics, but GT2 is about the *initializer* (creates the topology), not the *bootstrapper* (activates enforcement on an already-initialized repo). These are distinct steps: init creates branches, bootstrap configures hooks.
- D25 says init creates `now`, `meta`, and `provenance/scaffold`. Init must move the pre-existing template branch to `provenance/scaffold` and create the membrane branches from a fresh common root.
- The repo is currently a GitHub template scaffold — init transforms it into a membrane topology. The init command lives in the pre-init scaffold and is consumed once.

## Scope Boundary

In scope:
- decide the user-facing init command name and invocation
- decide whether init may rewrite local history (force-push, rebase, etc.)
- decide partial-success semantics: is the repo left in a recoverable state? how?
- decide re-run semantics: idempotent, error, or conditional?
- decide the relationship between init and bootstrap (are they one step or two?)
- record the CLI contract in `decisions.md`

Out of scope:
- implementing the init command (that is GT3)
- implementing bootstrap.sh (that is GT6)
- resolving D18 (enforcement source placement) or D19 (source language)
- resolving D6-PATHS (submodule path policy) — that is GT4
- defining `.gitmodules` schema — that is GT4

## Success Condition

- a clear CLI contract exists for the init command: name, arguments, preconditions, postconditions
- idempotence/recovery model is explicit: what happens on re-run, partial failure, and success
- the distinction between init (topology creation) and bootstrap (enforcement activation) is clear
- GT3 can implement the initializer without making hidden product decisions

## Stress Test

- partial-failure case: init creates the common root and `now` but fails before creating `meta` — what state is the repo in? can the operator recover?
- re-run case: init succeeds, operator runs init again — does it error, no-op, or destructively recreate?
- pre-existing work case: operator has made commits on the template's default branch before running init — does init preserve, warn, or refuse?
- agent case: a coding agent runs init non-interactively — does the contract support non-interactive execution?

## Audit Target

Audit these claims after GT2 lands:
- the init CLI contract is stated once in design authority, not split across roadmap and implementation
- the idempotence model is explicit enough that GT3 can implement detection of "already initialized" state
- no enforcement or schema decisions leaked into the init contract (those belong to GT4, GT6, GT7)
- the init/bootstrap distinction is clear and does not create a hidden dependency or ordering confusion

## Verification

- `rg -n "GT2|init|idempoten|recovery|bootstrap|partial" roadmap.md decisions.md`
- manual check that `decisions.md` contains the init CLI contract and recovery semantics
- manual check that the init/bootstrap boundary is clear and non-overlapping
