Create a new future branch grounded in a past branch, and register it in the now-branch composition.

## Context

Future branches (`future/<name>`) represent grounded speculation. They:
- Must descend from a declared past branch (the **grounding** constraint)
- Are declared in `.gitmodules` with `membrane-role = future` and `membrane-lineage = past/<lineage>`
- Can be retried, rebased, or abandoned — unlike past branches they are mutable

The grounding constraint enforced by `check-future-grounding.sh` verifies that the future pin is an ancestor-or-equal descendant of the declared past lineage pin.

## Arguments

$ARGUMENTS — `<name> [<past-branch>] [<start-commit>]`

- `<name>` — the future branch name suffix (result: `future/<name>`)
- `<past-branch>` — the past branch to ground in (e.g., `past/v1`). If omitted, list available past branches and ask.
- `<start-commit>` — where to branch from (default: current tip of `<past-branch>`)

## What to do

1. **Validate preconditions**:
   - Confirm membrane is initialized and we have at least one past branch registered in `.gitmodules`.
   - Confirm `<past-branch>` exists and has a valid pin in `.gitmodules`.
   - Confirm no existing branch named `future/<name>`.

2. **Resolve the start point**:
   - If `<start-commit>` is provided, verify it is a descendant of the past branch's current pin:
     `git merge-base --is-ancestor <past-pin> <start-commit>`
   - If not provided, use the tip of `<past-branch>`.

3. **Create the future branch**:
   - `git branch future/<name> <start-commit>`

4. **Register in `.gitmodules`** on the `now` branch:
   ```
   [submodule "future/<name>"]
       path = future/<name>
       url = .
       membrane-role = future
       membrane-lineage = <past-branch>
   ```
   - Update the submodule index entry with the start commit.

5. **Commit to `now`**:
   - Stage `.gitmodules` and the new submodule entry.
   - Commit message: `register future branch: future/<name> grounded in <past-branch>`

6. **Report**:
   - Branch created, grounded in which past branch, at which commit
   - Remind: "Work on future/<name>, then graduate it with /future-graduate <name>"

## Naming conventions

- Use lowercase, hyphen-separated names: `future/new-auth`, `future/refactor-api`, `future/experiment-xyz`
