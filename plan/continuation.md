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

- **Node ID:** GT3
- **Title:** Create common-root membrane topology in a generated repo
- **Status:** ACTIVE

## Why now

GT1 and GT2 are both closed. GT1 settled the canonical skeleton, branch naming (D24), initialized branch set (D25), provenance invariants (D26), and planning-file placement (D27). GT2 settled the initializer command contract (D28), provenance preservation (D29), marker-based idempotence (D30), and local-only scope boundary (D31). GT3 is now unblocked and is the sole entry point to the implementation spine — GT5, GT6, and GT12 all depend on GT3.

## Dependencies

- `decisions.md` §7 (D28–D31: init command contract, provenance, idempotence, scope)
- `decisions.md` §1.4–1.5 (D24–D26: branch naming, initialized set, provenance invariants)
- `decisions.md` §2.3–2.4 (D3-LAYOUT, D27: now-branch skeleton, planning files)
- `roadmap.md` (GT3 node definition and acceptance criteria)

## Output Files

- `init.sh` (the initializer script, living on the pre-init scaffold branch)
- `decisions.md` (only if implementation reveals a design gap requiring a new decision)
- `roadmap.md` (only if GT3 changes downstream boundaries)
- `continuation.md` (refresh state while GT3 remains active)

## Local Context

- GT3 is a C (implementation) node. The design decisions are settled; this is about writing `init.sh`.
- The eight initialization steps from §7.4 are the implementation contract:
  1. Create root ref (`refs/membrane/root`)
  2. Record provenance (`provenance/scaffold`)
  3. Create `now` from root
  4. Create `meta` from root
  5. Seed `now` (canonical skeleton)
  6. Seed `meta` (minimal content)
  7. Seed planning files (`plan/` on `now`)
  8. Checkout `now`
- Each step must be independently guarded for idempotence per D30.
- Init is purely additive per D29 — it never modifies or deletes existing refs.
- The init script is POSIX shell, non-interactive, meaningful exit codes per D28.
- `refs/membrane/root` is the primary initialization marker per D30.
- The now-branch skeleton layout is defined in D3-LAYOUT §2.3.
- Planning files are defined in D27 §2.4 — five files with protocol headers.
- Initial `.gitmodules` declares only the `meta` submodule per D25.

## Scope Boundary

In scope:
- implement `init.sh` following the eight-step contract
- create the empty common root commit and store it as `refs/membrane/root`
- create `now`, `meta`, and `provenance/scaffold` branches
- seed `now` with the canonical skeleton (`.now/hooks/`, `bootstrap.sh`, `.gitmodules`, `.gitignore`)
- seed `meta` with minimal initial content
- seed `plan/` with the five planning files and protocol headers
- implement step-level idempotence guards
- implement re-run detection (already-initialized → no-op exit 0)

Out of scope:
- implementing `bootstrap.sh` (GT6)
- implementing enforcement logic or hook content beyond stub launchers (GT7+)
- resolving D6-PATHS (submodule path policy — GT4)
- resolving D18 (enforcement source placement) or D19 (source language)
- any hosted platform configuration (D31)

## Success Condition

- A fresh repo created from the template can be initialized with `./init.sh` into the canonical branch topology.
- `git merge-base` across any pair of membrane branches (`now`, `meta`) resolves to the common root at `refs/membrane/root`.
- `provenance/scaffold` shares no commit ancestry with membrane branches.
- Re-running `./init.sh` on an already-initialized repo prints a no-op message and exits 0.
- Partial failure at any step can be recovered by re-running `./init.sh`.
- The now branch carries the canonical skeleton layout per D3-LAYOUT.
- The five planning files exist in `plan/` with protocol headers per D27.

## Stress Test

- Run init on a repo with no pre-init commits (bare template clone) — does it succeed?
- Run init on a repo with extra pre-init commits — does `provenance/scaffold` include them?
- Kill init after step 3 (branches created, not yet seeded) — does re-run complete cleanly?
- Run init twice in succession — does the second invocation no-op exit 0?
- Run init when a branch named `now` already exists but does NOT descend from a membrane root — does init correctly identify this as uninitialized?
- Verify `git merge-base now meta` resolves to the commit at `refs/membrane/root`.
- Verify `git merge-base --is-ancestor` fails between `provenance/scaffold` and `now`.

## Audit Target

Audit these claims after GT3 lands:
- the eight steps from §7.4 are implemented in order, each with an idempotence guard
- `refs/membrane/root` is created and used as the sole initialization marker
- the init script is purely additive — no existing refs are modified or deleted (D29)
- the now-branch skeleton matches D3-LAYOUT §2.3
- the planning files match D27 §2.4 protocol headers
- the init script is POSIX shell, non-interactive, exits 0 on success/already-initialized and non-zero on failure (D28)
- no enforcement logic or bootstrap activation leaked into init (those belong to GT6, GT7+)

## Verification

- `git rev-parse refs/membrane/root` — the root ref exists
- `git merge-base now meta` equals `refs/membrane/root`
- `git merge-base --is-ancestor provenance/scaffold now` — fails (disjoint ancestry)
- `git log --oneline now -- .now/hooks/` — hook stubs exist
- `git log --oneline now -- bootstrap.sh` — bootstrap.sh exists
- `git log --oneline now -- .gitmodules` — meta submodule declared
- `git log --oneline now -- plan/` — five planning files exist
- `./init.sh && echo $?` on already-initialized repo — prints 0
