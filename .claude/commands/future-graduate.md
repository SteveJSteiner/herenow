Graduate a future branch by advancing its past lineage to incorporate the future work, then retiring the future from the composition.

## Context

Graduation is the process of promoting settled future work into the past. It involves:
1. The future branch's tip becoming the new tip of its past lineage branch
2. Advancing the past pin in `.gitmodules` to that new tip (monotonicity preserved since future descends from past)
3. Removing the future submodule entry from `.gitmodules` (retirement)
4. Committing the updated composition to `now`

This is the normal lifecycle end for a future branch. Alternatively, a future can be abandoned (removed without advancing past).

## Arguments

$ARGUMENTS — `<future-name> [--abandon]`

- `<future-name>` — the future branch to graduate (e.g., `future/new-auth` or just `new-auth`)
- `--abandon` — instead of graduating, remove the future entry without advancing past

## What to do

### For graduation (default):

1. **Validate**:
   - Confirm `future/<name>` exists and is registered in `.gitmodules` with a valid `membrane-lineage`.
   - Get the future's current pin from `.gitmodules` index.
   - Get the past lineage branch and its current pin.
   - Verify monotonicity: `git merge-base --is-ancestor <past-pin> <future-pin>` — future must descend from past.

2. **Fast-forward the past branch**:
   - `git branch -f <past-lineage> <future-pin>` to advance the past branch tip.
   - This is safe because we just verified the future descends from past.

3. **Update `.gitmodules` on `now`**:
   - Update the past submodule pin to `<future-pin>`.
   - Remove the `[submodule "future/<name>"]` entry entirely.
   - Remove the future path from the git index: `git rm --cached future/<name>`.

4. **Commit to `now`**:
   - Commit message: `graduate future/<name> into <past-lineage>: advance to <short-commit>`

5. **Report**: past branch advanced, future branch retired, new composition state.

### For abandonment (`--abandon`):

1. Confirm the future entry exists in `.gitmodules`.
2. Remove the `[submodule "future/<name>"]` entry.
3. Remove from index: `git rm --cached future/<name>`.
4. Commit: `retire future/<name>: abandoned`
5. Optionally delete the branch: ask the user before deleting `future/<name>`.
6. Report: future removed, past branch unchanged.
