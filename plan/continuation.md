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

- **Node ID:** GT6
- **Title:** Bootstrap governed now-branch environment
- **Status:** ACTIVE

## Why now

GT3 is complete. The membrane branch topology exists: `refs/membrane/root`, `now`, `meta`, `provenance/scaffold`. The `now` branch carries the canonical skeleton with stub hooks and a placeholder `bootstrap.sh`. GT6 is the natural successor — it makes the initialized topology operational by implementing `bootstrap.sh`. Without GT6, a fresh checkout of `now` has no way to activate enforcement.

## Dependencies

- `decisions.md` §8 (D22: single bootstrap entry point, D23: submodule initialization strategy)
- `decisions.md` §5.1 (D14: two-layer enforcement, D16: hook launchers are POSIX shell)
- `decisions.md` §2.3 (D3-LAYOUT: `.now/hooks/` is the hooks directory, `core.hooksPath` points there)
- `decisions.md` §3.1 (D4: self-referencing submodules, known hazard re: recursive init)
- `decisions.md` §7.3 (D32: published-template invariant — membrane branches are init.sh outputs, not template content)
- `roadmap.md` (GT6 node definition and acceptance criteria)
- GT3 output: `init.sh` and the initialized branch topology it produces

## Output Files

- `init.sh` (on `main`): replace the stub bootstrap.sh heredoc in step 5 with the functional implementation
- `decisions.md` (only if implementation reveals a design gap requiring a new decision)
- `continuation.md` (refresh state while GT6 remains active)

## Local Context

- GT6 is a C (implementation) node. Most design decisions are settled; D23 (submodule init strategy) is OPEN but has a current leaning (selective).
- `bootstrap.sh` lives at the `now` branch root per D3-LAYOUT.
- Bootstrap is idempotent per D22 — safe to re-run on every fresh checkout.
- Bootstrap is separate from init per D28 — a second operator who clones an already-initialized repo runs only `bootstrap.sh`.
- The bootstrap contract from §8:
  1. Set `core.hooksPath` to `.now/hooks/`
  2. Build enforcement binary from source (if source exists and binary is missing/stale) — currently no source exists (D18/D19 still open), so this step is a no-op or a future-ready check
  3. Initialize submodules selectively (not recursively — D4 known hazard)
  4. Optionally create worktrees for standard roles (this is GT12 territory; bootstrap may prepare but should not require it)
- The hook stubs from GT3 are already in `.now/hooks/` — bootstrap just needs to point `core.hooksPath` there.
- The `meta` submodule is declared in `.gitmodules` with `url = ./` — bootstrap must initialize it non-recursively.
- Bootstrap must leave a clear recovery path if it fails mid-flight (D22).
- The existing `now`, `meta`, `provenance/scaffold` branches and `refs/membrane/root` in this repo are GT3 test artifacts, not template content (D32). They are not part of the published template surface.
- bootstrap.sh is authored as the heredoc embedded in `init.sh` step 5 (on `main`). The copy on the current `now` branch is a test artifact — GT6 does not edit it directly.
- All GT6 development happens on `main`. Testing runs in disposable clones initialized from scratch: clone scaffold, run `init.sh`, run `bootstrap.sh`, discard.

## Scope Boundary

In scope:
- implement functional `bootstrap.sh` following the §8 contract
- set `core.hooksPath` to `.now/hooks/`
- initialize the `meta` submodule non-recursively
- verify the working tree is ready for governed operations
- leave retryable state or explicit recovery instructions on failure
- update `init.sh` step 5 to seed the functional bootstrap instead of the stub

Out of scope:
- implementing enforcement logic in the hook stubs (GT7+)
- building enforcement binaries (no source exists yet — D18/D19 still open)
- worktree provisioning (GT12)
- submodule path policy (GT4/D6-PATHS)
- resolving D23 fully — use the current leaning (selective/non-recursive) and note if it proves insufficient
- cleaning up GT3 test artifacts (membrane branches/refs) from this repo — that is a pre-publication concern absorbed by GT14 (D32)

## Success Condition

- A fresh checkout of `now` becomes governed with `./bootstrap.sh`.
- `git config core.hooksPath` returns `.now/hooks/` after bootstrap.
- The `meta` submodule is initialized and checked out at `meta/`.
- Bootstrap does not recurse through self-referential submodule workflows (D4 hazard avoided).
- Re-running `bootstrap.sh` on an already-bootstrapped checkout is a safe no-op or idempotent refresh.
- Failure messages tell the operator what is missing and whether rerun is safe.

## Stress Test

Each scenario starts from a disposable clone of `main` (scaffold only). Run `init.sh` to create the membrane topology, then exercise `bootstrap.sh`.

- Run bootstrap on a freshly checked-out `now` — does it complete and set hooksPath?
- Run bootstrap twice — is the second run idempotent?
- Run bootstrap when `meta` submodule is already initialized — does it skip or update cleanly?
- Run bootstrap when `core.hooksPath` is already set to `.now/hooks/` — no-op or safe refresh?
- Delete `meta/` and re-run bootstrap — does it recover?
- Run bootstrap on a branch that is NOT `now` — does it fail with a clear message or proceed cautiously?
- Run bootstrap on a scaffold repo that has NOT been initialized — does it fail with a clear message?

## Audit Target

Audit these claims after GT6 lands:
- `core.hooksPath` is set to `.now/hooks/` and the hooks are executable
- the `meta` submodule is initialized non-recursively (no self-referential recursion)
- bootstrap is idempotent — safe to re-run
- bootstrap does not activate enforcement logic (that belongs to GT7+)
- bootstrap failure leaves a recoverable state with clear instructions
- `init.sh` seeds the functional `bootstrap.sh`, not the stub

## Verification

- `./bootstrap.sh` on fresh `now` checkout — exits 0
- `git config core.hooksPath` — returns `.now/hooks/`
- `ls meta/README.md` — meta submodule content is present
- `git submodule status` — meta submodule is initialized, no recursive entries
- `./bootstrap.sh` again — idempotent, exits 0
- `rm -rf meta && ./bootstrap.sh` — recovers meta submodule
