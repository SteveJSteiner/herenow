Provision or inspect worktrees for temporal membrane roles.

## Context

The Temporal Membrane's `provision-worktrees.sh` script creates filesystem worktrees for each temporal role, making the branch structure tangible on disk:
- `worktrees/now/` → `now` branch
- `worktrees/meta/` → `meta` branch
- `worktrees/past/<name>/` → each registered past branch
- `worktrees/future/<name>/` → each registered future branch

Worktrees are ergonomic — you can work in each role's directory without switching branches. They are not required for enforcement to work.

## Arguments

$ARGUMENTS — one of:
- (empty) — provision all worktrees for registered branches
- `list` — show existing worktrees and their status
- `<branch-name>` — provision a worktree for a specific branch only
- `clean` — remove worktrees for branches that no longer exist

## What to do

### If "list" or inspecting:
- Run `git worktree list --porcelain` and format the output showing branch, path, and status.
- Cross-reference with `.gitmodules` to show which temporal roles have worktrees vs. are missing.

### If provisioning (default or specific branch):
1. Check if `provision-worktrees.sh` exists (at `.now/src/provision-worktrees.sh` or in the repo root).
2. If the script exists, run it (possibly with the branch argument).
3. If the script is not present (scaffold state before init), provision manually:
   - For each branch in $ARGUMENTS (or all temporal branches from `.gitmodules` + `now` + `meta`):
     - `git worktree add worktrees/<role>/<name> <branch-name>`
   - Handle existing worktrees gracefully (skip with a note).
4. Report which worktrees were created, already existed, or failed.

### If "clean":
- List worktrees whose branches have been deleted.
- For each stale worktree, ask for confirmation, then run `git worktree remove <path>`.
- Run `git worktree prune` to clean up stale metadata.

## Notes

- The `worktrees/` directory should be gitignored — check `.gitignore` and add it if missing.
- Worktree paths containing the submodule `meta` require the meta submodule to be initialized first.
