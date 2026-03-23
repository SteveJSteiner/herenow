Advance a past branch's submodule pin to a new (later) commit.

## Context

Past branches must only advance forward — their pins in `.gitmodules` can only move to commits that are descendants of the current pin. This is the **past monotonicity** constraint enforced by `check-past-monotonicity.sh`.

Advancing a past pin means:
1. Verifying the new commit is a descendant of the current pin (`git merge-base --is-ancestor`)
2. Updating the submodule index entry on the `now` branch
3. Committing the change to `now`

## Arguments

$ARGUMENTS — `<branch-name> [<new-commit>]`

- `<branch-name>` — the past branch to advance (e.g., `past/v1` or just `v1`)
- `<new-commit>` — the commit to advance to (default: current tip of that branch)

If `<branch-name>` is missing, list available past branches and ask the user to choose.
If `<new-commit>` is missing, use the current tip of the named branch.

## What to do

1. **Resolve inputs**:
   - Normalize branch name to `past/<name>` if not already prefixed.
   - Resolve `<new-commit>` to a full SHA: `git rev-parse <new-commit>`.
   - Find the current pin from `.gitmodules` index: `git ls-files -s past/<name>` or parse `.gitmodules`.

2. **Validate monotonicity**:
   - Run: `git merge-base --is-ancestor <current-pin> <new-commit>`
   - If this fails (new-commit is NOT a descendant), abort and explain: "Cannot advance past/<name>: <new-commit> is not a descendant of current pin <current-pin>. Past branches may only move forward."

3. **Validate the past branch tip**:
   - Also verify `<new-commit>` is reachable from `past/<name>`: `git merge-base --is-ancestor <new-commit> past/<name>` or `git branch --contains <new-commit>`.

4. **Update the pin on `now`**:
   - Ensure we are on the `now` branch.
   - Update the submodule pointer: `git update-index --cacheinfo 160000,<new-commit>,past/<name>`
   - Stage `.gitmodules` if the URL or other fields changed.

5. **Commit**:
   - Commit message: `advance past/<name>: <short-old> -> <short-new>`
   - The pre-commit hook will re-validate monotonicity — if it passes, report success.

6. **Report**:
   - Previous pin, new pin, commit count advanced (if determinable via `git log --oneline <old>..<new> | wc -l`)
