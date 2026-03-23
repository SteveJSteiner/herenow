Commit a composition change to the `now` branch, with preflight validation.

## Canonical validator

The canonical composition validator for this membrane is:

```
.now/src/check-composition.sh
```

This is the single authoritative definition of that path. Both the pre-commit hook (`.now/hooks/pre-commit`) and this command's preflight step call this same script. No other validator path is used.

To run preflight manually (outside of a commit):
```
<NOW_ROOT>/.now/src/check-composition.sh
```

## Context

The `now` branch is the composition surface. Every commit to it is gated by the pre-commit hook, which calls the canonical validator. This command runs the same validator as an explicit preflight before committing, so hook failures are diagnosed before git is invoked.

`git commit --dry-run` is not used for preflight. It can trigger unrelated hooks and produces noisy output for the wrong reasons. The canonical validator is called directly.

## Resolving the now authority surface

All operations target `now` directly. Branch switching in the operator's current worktree is not the default.

Resolution order:
1. **now worktree exists**: `git worktree list --porcelain | awk '/^worktree/{w=$2} /branch refs\/heads\/now/{print w; exit}'`
2. **Current checkout is now**: `git symbolic-ref --short HEAD` == `now`
3. **Neither**: report "No now worktree found and current branch is not now." Suggest `/worktrees now` to provision one. Stop.

The resolved directory is `$NOW_ROOT` for all subsequent steps.

## Arguments

$ARGUMENTS — the commit message, or a short description of what is being committed

If no message is given, ask the user before proceeding.

## Operation sequence

### 1. Resolve now authority surface

Determine `$NOW_ROOT` as described above.

### 2. Show staged and unstaged composition changes

```
git -C $NOW_ROOT status
git -C $NOW_ROOT diff --stat HEAD
git -C $NOW_ROOT diff --cached --stat
```

Report what will be included in the commit. If nothing is staged and nothing is modified, report that and stop.

### 3. Run canonical preflight validator

```
$NOW_ROOT/.now/src/check-composition.sh
```

If the validator is not present or not executable:
- Report "Canonical validator not found at .now/src/check-composition.sh"
- Check whether bootstrap has been run: `git config core.hooksPath`
- If not bootstrapped, direct the operator to run `/membrane-init bootstrap` first
- Stop

If the validator exits non-zero:
- Report its full output verbatim
- Identify which constraint failed (past monotonicity, future grounding, meta self-consistency, or composition cross-check) based on the output
- Stop. Do not proceed to commit.

If the validator exits zero: report "Preflight passed."

### 4. Stage files if needed

If nothing is staged yet, ask the operator which files to stage. Do not auto-stage all changes.

### 5. Commit

```
git -C $NOW_ROOT commit -m "<message>"
```

The pre-commit hook will run the canonical validator again. This is expected — it is the same check.

If the commit is rejected by the hook:
- Report the hook output verbatim
- Identify the specific membrane constraint that failed
- Do not retry automatically

### 6. Confirm

```
git -C $NOW_ROOT log --oneline -3
```

Show the result. Report the new commit hash and message.

## Failure and recovery

**Mutated first**: the git index is modified when files are staged in step 4, before the commit.

**Partial state that can remain**: staged changes that were not committed (if the hook rejects or the commit fails for another reason).

**Detect**:
```
git -C $NOW_ROOT diff --cached
```

**Recover** — two options:
```
# option A: fix the violation and retry the commit
# (edit the staged files to resolve the constraint failure, then re-run /now-commit)

# option B: unstage everything and start over
git -C $NOW_ROOT reset HEAD
```
