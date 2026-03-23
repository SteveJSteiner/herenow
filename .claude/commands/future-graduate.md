Graduate a future branch into its past lineage, then retire the future entry from the now composition.

## Context

Graduation promotes settled future work into the past. It has two distinct phases that must happen in order:

1. **Advance the past ref** — `refs/heads/past/<lineage>` moves to the future pin
2. **Update now composition** — the past gitlink advances and the future entry is removed

This order is required by the membrane's consistency model. A state where the past ref has advanced but `now` still carries the older past pin is acceptable lag — the membrane permits pins to lag tips. The reverse (now claiming a past pin the ref has not yet reached) is not acceptable.

The past ref is advanced using a **compare-and-swap** (`git update-ref` with an expected old value), not a blind force move. This prevents silently overwriting concurrent changes.

`git branch -f` is not used. Do not substitute it.

## Resolving the now authority surface

All composition writes target `now` directly.

Resolution order:
1. **now worktree exists**: `git worktree list --porcelain | awk '/^worktree/{w=$2} /branch refs\/heads\/now/{print w; exit}'`
2. **Current checkout is now**: `git symbolic-ref --short HEAD` == `now`
3. **Neither**: suggest `/worktrees now` and stop

## Arguments

$ARGUMENTS — `<future-name> [--abandon]`

- `<future-name>` — e.g. `future/new-auth` or just `new-auth` (normalized to `future/<name>`)
- `--abandon` — retire the future entry from composition without advancing past (see below)

## Graduation operation sequence

### 1. Gather state

```
# read future pin from now
FUTURE_PIN=$(git rev-parse now:future/<name>)

# read lineage from now composition
LINEAGE=$(git show now:.gitmodules | awk '/\[submodule "future\/<name>"\]/{f=1} f && /membrane-lineage/{print $3; exit}')
# normalize to full path: past/<lineage-suffix>

# read current past pin from now
PAST_PIN=$(git rev-parse now:past/<lineage>)

# read current past ref tip
OLD_PAST_TIP=$(git rev-parse refs/heads/past/<lineage>)
```

If any of these are unresolvable, report the specific failure and stop.

### 2. Validate grounding

```
git merge-base --is-ancestor $PAST_PIN $FUTURE_PIN
```

If this fails: abort. "Cannot graduate future/<name>: future pin `$FUTURE_PIN` does not descend from the current past pin `$PAST_PIN`. The future must descend from its declared past lineage."

### 3. Advance the past ref (compare-and-swap)

```
git update-ref refs/heads/past/<lineage> $FUTURE_PIN $OLD_PAST_TIP
```

If this fails because `refs/heads/past/<lineage>` no longer equals `$OLD_PAST_TIP`, report the conflict and stop. The past ref may have been updated by another operation since step 1.

**After this point, the past ref is advanced.** If subsequent steps fail, see the safe partial state section below.

### 4. Update the past gitlink on now

```
git -C <NOW_ROOT> update-index --cacheinfo 160000,$FUTURE_PIN,past/<lineage>
```

### 5. Remove the future entry from now composition

Remove the `[submodule "future/<name>"]` stanza from `.gitmodules` in the now working directory.

Stage all changes:
```
git -C <NOW_ROOT> add .gitmodules
git -C <NOW_ROOT> update-index --force-remove future/<name>
```

### 6. Commit on now

```
git -C <NOW_ROOT> commit -m "graduate future/<name> into past/<lineage>: <short-old-past> -> <short-future>"
```

If the hook rejects the commit, report its output verbatim.

### 7. Report

- `refs/heads/past/<lineage>` advanced from `<short-old-past>` to `<short-future>`
- Composition: past pin updated, future entry retired

---

## Safe partial state

**If step 3 succeeded but steps 4–6 did not complete**, the repository is in a safe lag state:

- `refs/heads/past/<lineage>` points to `$FUTURE_PIN`
- `now` still pins `past/<lineage>` to `$PAST_PIN` (the older commit)
- `future/<name>` may still be present in `now` composition

This is safe because the membrane permits past pins to lag past ref tips. No constraint is violated.

**Detect this state**:
```
git rev-parse refs/heads/past/<lineage>          # should be FUTURE_PIN
git rev-parse now:past/<lineage>                 # should still be PAST_PIN if lagging
git show now:.gitmodules | grep "future/<name>"  # future entry still present?
git rev-parse now:future/<name> 2>/dev/null      # future gitlink still present?
```

**Recover** — finish the composition update:
```
# re-run this command: /future-graduate <name>
# or manually:
git -C <NOW_ROOT> update-index --cacheinfo 160000,$FUTURE_PIN,past/<lineage>
# edit .gitmodules to remove the future/<name> stanza, then:
git -C <NOW_ROOT> add .gitmodules
git -C <NOW_ROOT> update-index --force-remove future/<name>
git -C <NOW_ROOT> commit -m "graduate future/<name> into past/<lineage>: <short-old-past> -> <short-future>"
```

**Optional rollback** — if you want to undo the already-advanced past ref before finishing composition (e.g., you decide not to graduate after all):
```
git update-ref refs/heads/past/<lineage> $OLD_PAST_TIP $FUTURE_PIN
```
This is optional. The normal recovery path is to finish the composition update, not to undo the safe lag state.

---

## Abandonment (`--abandon`)

Abandonment retires the future entry from composition without advancing the past ref.

### 1. Validate

```
git show now:.gitmodules | grep "future/<name>"  # entry must exist
git rev-parse now:future/<name>                  # gitlink must be present
```

### 2. Remove the future entry from now composition

Remove the `[submodule "future/<name>"]` stanza from `.gitmodules` in the now working directory.

```
git -C <NOW_ROOT> add .gitmodules
git -C <NOW_ROOT> update-index --force-remove future/<name>
```

### 3. Commit on now

```
git -C <NOW_ROOT> commit -m "retire future/<name>: abandoned"
```

### 4. Optionally delete the branch ref

This is separate from composition retirement and requires explicit confirmation:
```
git update-ref -d refs/heads/future/<name>
```

Ask before running this. A retired-but-still-existing branch ref is harmless.

## Failure and recovery for abandonment

**Mutated first**: `.gitmodules` and the gitlink are staged on `now` before committing.

**Partial state**: staged changes present but not committed.

**Detect**:
```
git -C <NOW_ROOT> diff --cached
```

**Recover**:
```
# option A: commit the staged retirement
git -C <NOW_ROOT> commit -m "retire future/<name>: abandoned"

# option B: discard and start over
git -C <NOW_ROOT> checkout -- .gitmodules
git -C <NOW_ROOT> update-index --add --cacheinfo 160000,<original-pin>,future/<name>
```
