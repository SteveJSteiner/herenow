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

- **Node ID:** GT12
- **Title:** Worktree provisioning and operator ergonomics
- **Status:** READY

## Why now

GT11 is complete — meta self-consistency mechanism implemented and tested (10/10 assertions, D12 closed). GT12 is unblocked by GT3 (init.sh creates the branch structure that worktrees attach to). GT12 is the last dependency for GT13 (end-to-end smoke), which requires GT10 + GT11 + GT12.

## Dependencies

- GT3 output: `init.sh` creates `now`, `meta`, and `provenance/scaffold` branches — the branches that worktrees will be created from
- D6-PATHS (CLOSED): submodule paths are flat at repo root, role in the key not the path
- D3-LAYOUT (CLOSED): `.now/` is the enforcement namespace, `plan/` is the planning namespace
- Current branch structure: `now`, `meta`, `main`, `provenance/scaffold`

## Output Files

- Worktree provisioning script (e.g., `.now/src/provision-worktrees.sh` or a subcommand in `bootstrap.sh`)
- Test script validating worktree creation and safety
- `continuation.md` (refresh state while GT12 remains active)

## Local Context

- GT12 is a C node. The deliverable is working code with tests.
- Worktrees are an ergonomic layer. The command must be safe to skip — worktrees are convenience, not a hidden dependency for enforcement.
- Standard worktrees: one for `now`, one for `meta`, at least one `past`, at least one `future`. The exact past/future branches depend on what `init.sh` created and what submodules exist.
- Worktrees should be created at conventional locations relative to the repo root. The provisioner reads `.gitmodules` to discover which branches/roles exist.
- The provisioner should be idempotent: re-running does not break existing worktrees.
- Edge cases: what if a worktree already exists at the target path? What if the branch doesn't exist? What if the user has uncommitted changes in an existing worktree?

## Scope Boundary

In scope:
- Implement worktree provisioning command
- Create worktrees for now, meta, and any declared past/future submodule branches
- Idempotent operation (safe to re-run)
- Test with controlled scenarios

Out of scope:
- Enforcement changes (GT10/GT11 complete)
- End-to-end smoke scenarios (GT13)
- GitHub template packaging (GT14)

## Success Condition

- Standard worktrees for `now`, one `meta`, and at least one `past` or `future` can be created from the initialized repo (GT12 acceptance).
- The command is safe to skip; worktrees remain an ergonomic layer, not a hidden dependency (GT12 acceptance).

## Stress Test

- Does the provisioner create worktrees for all declared submodule branches?
- Is the provisioner idempotent (re-run doesn't break existing worktrees)?
- Does it handle missing branches gracefully?
- Does it handle already-existing worktrees gracefully?
- Does it work immediately after `init.sh` on a fresh repo?
- Can enforcement operate correctly without worktrees being provisioned?

## Audit Target

- Provisioner script exists and is executable
- Worktrees are created at conventional locations
- Re-running does not produce errors or break existing state
- Enforcement works with and without worktrees

## Verification

- Test script exercises creation, idempotence, and edge cases with pass/fail assertions
- Manual verification that enforcement hooks still work without worktrees
