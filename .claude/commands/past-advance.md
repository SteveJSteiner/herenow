Advance the composition pin for a past branch on `now` to a later commit.

## Context

This command advances the **pin** — the gitlink entry recorded in `now`'s composition — to a new commit already reachable from the corresponding `refs/heads/past/<name>` ref. It does not move the past branch ref itself.

The pin and the branch ref are distinct:
- `refs/heads/past/<name>` — the branch tip; may be ahead of the pin
- `now`'s gitlink for `past/<name>` — the declared settled point; this is what this command advances

Pin lag (tip ahead of pin) is normal. This command resolves that lag by catching the pin up to a chosen commit on the past branch.

The past monotonicity constraint requires that the new pin is a descendant of the current pin. A pin may never move backward.

## Resolving the now authority surface

All composition writes target `now` directly. Branch switching in the operator's current worktree is not the default.

Resolution order:
1. **now worktree exists**: `git worktree list --porcelain | awk '/^worktree/{w=$2} /branch refs\/heads\/now/{print w; exit}'`
2. **Current checkout is now**: `git symbolic-ref --short HEAD` == `now`
3. **Neither**: suggest `/worktrees now` and stop

## Arguments

$ARGUMENTS — `<branch-name> [<target-commit>]`

- `<branch-name>` — e.g. `past/v1` or just `v1` (normalized to `past/<name>`)
- `<target-commit>` — commit to advance the pin to (default: current tip of `refs/heads/past/<name>`)

If `<branch-name>` is missing, list registered past entries from `git show now:.gitmodules` and ask.

## Operation sequence

### 1. Resolve inputs

```
# normalize name
BRANCH="past/<name>"

# resolve target
TARGET=$(git rev-parse <target-commit>)          # or: git rev-parse refs/heads/past/<name>

# read current pin from now composition
CURRENT_PIN=$(git rev-parse now:past/<name>)
```

If `CURRENT_PIN` is unresolvable, report "past/<name> is not registered in now composition" and stop.

### 2. Validate monotonicity

```
git merge-base --is-ancestor $CURRENT_PIN $TARGET
```

If this fails: abort. "Cannot advance past/<name>: target is not a descendant of current pin `$CURRENT_PIN`. Past pins may only move forward."

### 3. Validate target is on the past branch

```
git merge-base --is-ancestor $TARGET refs/heads/past/<name>
```

If this fails: abort. "Target commit is not reachable from refs/heads/past/<name>. The pin must point to a commit on the past branch."

### 4. Update the gitlink on now

```
git -C <NOW_ROOT> update-index --cacheinfo 160000,$TARGET,past/<name>
```

No `.gitmodules` edit is needed unless the entry itself is new (use `/past-create` for that case).

### 5. Commit on now

```
git -C <NOW_ROOT> commit -m "advance past/<name>: <short-old> -> <short-new>"
```

The pre-commit hook will re-validate monotonicity. If it rejects the commit, report the hook output verbatim.

### 6. Report

- Previous pin: `<short-old>`
- New pin: `<short-new>`
- Commits advanced: `git log --oneline <CURRENT_PIN>..$TARGET | wc -l`

## Failure and recovery

**Mutated first**: the gitlink is staged on `now` in step 4, before committing.

**Partial state that can remain**: gitlink updated in the now index but not committed (if the commit step fails or is interrupted).

**Detect**:
```
git -C <NOW_ROOT> diff --cached                  # staged but uncommitted changes?
git -C <NOW_ROOT> diff --cached -- past/<name>   # gitlink staged?
```

**Recover** — the staged change is safe to commit or reset:
```
# option A: commit the already-staged advance
git -C <NOW_ROOT> commit -m "advance past/<name>: <short-old> -> <short-new>"

# option B: discard the staged advance and start over
git -C <NOW_ROOT> update-index --cacheinfo 160000,$CURRENT_PIN,past/<name>
git -C <NOW_ROOT> reset HEAD -- past/<name>
```
