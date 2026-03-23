Compose and commit a change to the now branch, with enforcement pre-validation.

## Context

The `now` branch is the present composition surface — it holds submodule pins, enforcement hooks, and planning files. Every commit to `now` is checked by git hooks for:
- Past monotonicity (pins only advance)
- Future grounding (futures descend from their declared past)
- Atomic composition consistency
- Meta self-consistency

This skill helps you commit a composition change with confidence, running a pre-flight check before the actual commit so that hook failures don't catch you by surprise.

## Arguments

$ARGUMENTS — `"<commit message>"` or a description of what you want to commit

If no message is given, ask the user what change they are committing.

## What to do

1. **Verify branch**: Confirm we are on `now`. If not, ask whether to switch or abort.

2. **Show staged and unstaged changes**: Run `git status` and `git diff --stat HEAD` to see what will be committed.

3. **Pre-flight composition check** (before committing):
   - Run `.now/src/check-composition.sh` directly if it exists and is executable.
   - If the check fails, report the specific violation(s) and stop — do NOT proceed to commit.
   - If the check passes, report "Composition valid — proceeding."

4. **Confirm the commit message** with the user if $ARGUMENTS is a description rather than a quoted message. Suggest a message following the existing commit style in this repo (`git log --oneline -10` to see style).

5. **Stage files** if needed — ask the user which files to stage if nothing is staged yet.

6. **Commit**: `git commit -m "<message>"`
   - The enforcement hooks will run automatically.
   - If the commit fails due to a hook violation, report the exact hook output and explain what constraint was violated.

7. **Post-commit**: Show `git log --oneline -3` to confirm the commit landed.

## Common composition changes

- Registering a new past branch → use `/past-create`
- Advancing a past pin → use `/past-advance`
- Registering a future branch → use `/future-create`
- Graduating a future → use `/future-graduate`
- Updating planning files → commit directly with this skill
