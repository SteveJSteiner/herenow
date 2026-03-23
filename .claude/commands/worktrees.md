Provision or inspect worktrees for temporal membrane roles.

## Context

Worktrees make the membrane's branch structure tangible on disk. Each temporal role can have a corresponding directory:
- `worktrees/now/` → `now` branch
- `worktrees/meta/` → `meta` branch
- `worktrees/past/<name>/` → each registered past branch
- `worktrees/future/<name>/` → each registered future branch

Worktrees are ergonomic infrastructure. Enforcement does not depend on them. Their primary value is letting the operator work in each role's directory without switching branches.

Branch names used for provisioning are always derived from `now` composition (via `git show now:.gitmodules`) and the known membrane authority surfaces (`now`, `meta`). They are never assumed from the current checkout.

## Arguments

$ARGUMENTS — one of:
- (empty) — provision worktrees for all membrane roles not yet covered
- `list` — show existing worktrees cross-referenced against membrane roles
- `<branch-name>` — provision a worktree for one specific branch (e.g. `now`, `past/v1`, `future/new-auth`)
- `clean` — detect and remove stale worktrees

## What to do

### `list`

1. Run `git worktree list --porcelain` to get all active worktrees.
2. Read composition from `now`: `git show now:.gitmodules` to get all registered branches.
3. Build the full membrane role set: `now`, `meta`, and every `path` declared in `.gitmodules`.
4. For each role, report one of:
   - **present** — a worktree exists pointing to that branch
   - **missing worktree** — the branch exists but no worktree covers it (informational, not a violation)
   - **invalid composition** — the branch is declared in composition but the ref does not exist (violation)
5. Show existing worktrees that do not correspond to any membrane role separately as "unrecognized."

### Provision (empty or `<branch-name>`)

1. If a specific branch is given, provision only that one. Otherwise provision all missing membrane roles.
2. For each branch to provision:
   - Confirm `refs/heads/<branch>` exists: `git rev-parse --verify refs/heads/<branch>`
   - Determine the worktree path: `worktrees/<branch>` (e.g. `worktrees/past/v1`)
   - Check whether a worktree already exists at that path or for that branch:
     ```
     git worktree list --porcelain | grep -F "branch refs/heads/<branch>"
     ```
   - If already present: skip and report "already present at <path>"
   - If not present: `git worktree add worktrees/<branch> <branch>`
3. Check `.gitignore` for `worktrees/` — if absent, note that it should be added to prevent accidental commits.
4. Report: created / skipped (already present) / failed for each branch attempted.

### `clean`

1. Run `git worktree list --porcelain` to find all worktrees.
2. For each worktree, check whether its branch ref still exists:
   ```
   git rev-parse --verify <branch-ref> 2>/dev/null
   ```
3. For each stale worktree (branch ref gone or worktree path missing from disk), report it and ask for confirmation before removing.
4. On confirmation:
   ```
   git worktree remove <path>
   ```
   If the path is already gone from disk:
   ```
   git worktree prune
   ```
5. Report what was removed.

## Notes

- `worktrees/` should be in `.gitignore`. If it is missing, add it before provisioning.
- The `meta` submodule requires initialization before its worktree is fully usable: `git -C worktrees/meta submodule update --init`.
- If a worktree add fails because the path already exists on disk but is not registered as a worktree, report the exact error and suggest either removing the directory or running `git worktree repair`.
