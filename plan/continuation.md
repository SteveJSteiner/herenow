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

- **Node ID:** GT17
- **Title:** Claude Code command contracts for governed operations
- **Status:** ACTIVE

## Why now

The membrane scaffold is ready for a repository-local Claude Code operator layer, but command contracts must be tightened so every operation is bound directly to files, scripts, and checkers that govern commit acceptance.

## Dependencies

- GT16 complete.
- Current scaffold behavior on `main` is authoritative until contradicted by source or tests.
- Existing enforcement files, hooks, helper scripts, and tests must be read before command prose is treated as settled.
- `plan/` can provide rationale but cannot override implementation behavior fixed in source.

## Output files

- `CLAUDE.md`
- `.claude/commands/README.md`
- `.claude/commands/membrane-status.md`
- `.claude/commands/modify-enforcement-source.md`
- `.claude/commands/create-past.md`
- `.claude/commands/create-future.md`
- `.claude/commands/advance-past.md`
- `.claude/commands/graduate-future.md`
- `.claude/commands/init-bootstrap-first-commit.md`
- `.claude/commands/now-commit.md`

## Local context

- `main` is template scaffold state, not initialized membrane state.
- `init.sh` establishes membrane refs/branches and seeds now/meta content.
- `bootstrap.sh` (seeded by `init.sh`) activates hooks and initializes local `meta` submodule.
- Governed commit acceptance flows through `.now/hooks/*` and `.now/src/check-composition.sh`.
- `check-meta-consistency.sh` reads the `meta` gitlink from the **index** and compares manifest hashes to working-tree enforcement files.
- `update-manifest.sh` updates `enforcement-manifest` on `meta`, stages new meta gitlink on `now`, and stages manifested enforcement files.
- Commands remain explicit slash commands under `.claude/commands/`; this task does not shift to skills.
- If a command cannot be written cleanly without apology, the exposed issue must be fixed in source or documented in the relevant source file before the command cites it.

## Scope boundary

### In scope

- Explicit command contracts for initialized, bootstrapped governed operation.
- Durable runtime authority in `CLAUDE.md`.
- Durable prose register/index/skeleton in `.claude/commands/README.md`.
- Read-only inspection command (`membrane-status`).
- Write flows: `modify-enforcement-source`, `create-past`, `create-future`, `advance-past`, `graduate-future`, `init-bootstrap-first-commit`, `now-commit`.

### Out of scope

- Auto-triggered `.claude/skills/` as primary interaction model.
- New membrane semantics.
- New helper scripts unless command writing exposes a source-level defect that must be fixed.
- Planning-maintenance commands.

## Success condition

This task is complete when:

1. Command contracts exist and are operationally usable under `.claude/commands/`.
2. `CLAUDE.md` establishes truth precedence, source-over-prose rule, and grounded vocabulary.
3. `.claude/commands/README.md` establishes register, command index, and mandatory skeleton.
4. Every write command includes truth sources, preconditions, steps, verification, failure protocol, and evidence to report.
5. `modify-enforcement-source` explicitly teaches index-pinned meta consistency and manifest-update atomic staging behavior.
6. Entry and bottom-out flows are explicit (`init-bootstrap-first-commit` and `now-commit`).
7. No command claims behavior contradicted by source or checked examples.
8. Any issue exposed while writing a clean command contract is either fixed in repository source or documented in the relevant source file before the command cites it.

## Verification

- Re-read and cross-check against:
  - `README.md`
  - `init.sh`
  - seeded `bootstrap.sh`
  - `.now/hooks/*`
  - `.now/src/immune-response.sh`
  - `.now/src/check-composition.sh`
  - `.now/src/validate-gitmodules.sh`
  - `.now/src/check-past-monotonicity.sh`
  - `.now/src/check-future-grounding.sh`
  - `.now/src/check-meta-consistency.sh`
  - `.now/src/update-manifest.sh`
  - `.now/src/create-past.sh`
  - `.now/src/create-future.sh`
  - `.now/src/advance-past.sh`
  - `.now/src/graduate-future.sh`
- Verify each command distinguishes scaffold vs initialized state, index vs working tree, helper script vs checker, and source authority vs rationale.
- Smoke commands in a disposable generated repo:
  1. generate from template,
  2. run `./init.sh`,
  3. run `./bootstrap.sh`,
  4. run `/membrane-status`,
  5. perform controlled enforcement edit through `/modify-enforcement-source`,
  6. create past/future,
  7. advance past and graduate future,
  8. confirm documented checks and outcomes match observed behavior.

## Stress test

- If `modify-enforcement-source` can be written without mentioning index-pinned meta state, the command is too abstract and fails.
- If command prose can use membrane vocabulary without file/command/checker references and still sound acceptable, the command fails.
- If `create-future` can be written with invented `.gitmodules` vocabulary and not be caught, the command fails.
- If prose can become bureaucratic or apologetic without violating the README register, the register is too weak and must be sharpened.

## Audit target

Audit each command line-by-line for:

- metaphor leakage where mechanism should be named,
- invented key names or branch semantics,
- commands-vs-skills drift,
- omission of stop conditions,
- omission of verification,
- omission of evidence reporting,
- collapse of index state into working-tree state,
- normalization of bypass behavior,
- prose that violates the established register.

<!-- continuation refreshed after commit 28fabd0; GT17 remains ACTIVE -->
