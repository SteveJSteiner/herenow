Show the current state of the temporal membrane.

## Context

The Temporal Membrane organizes a repository into temporal roles:
- `now` — present composition surface (submodule pins, hooks, enforcement)
- `meta` — self-governance (enforcement source)
- `provenance/scaffold` — provenance snapshot
- `past/*` — settled history branches (monotonic, append-only)
- `future/*` — grounded speculative branches (must descend from a declared past)

## What to do

Run these diagnostics and present a structured report:

1. **Branch inventory** — `git branch -a` filtered to show temporal roles. Group by role.

2. **Composition state** (if on `now` branch or `now` exists):
   - Read `.gitmodules` and extract all submodule entries with their `membrane-role` and `membrane-lineage` keys.
   - Show each submodule: name, path, role, current pin (commit hash from `git submodule status`).

3. **Enforcement status**:
   - Check `git config core.hooksPath` — is it set to `.now/hooks/`?
   - Check if `.now/hooks/` exists and is populated.
   - Report whether enforcement is active or not.

4. **Past monotonicity**: For each `past/*` submodule pin, note the current commit and whether the branch tip has advanced beyond it.

5. **Future grounding**: For each `future/*` submodule pin, verify it is a descendant of its declared `membrane-lineage` past branch. Show grounding status as valid/invalid/unknown.

6. **Meta self-consistency**: Check `git submodule status meta` if applicable; note if it shows `+` (modified) or `-` (uninitialized).

7. **Worktrees**: Run `git worktree list` and show which temporal roles have worktrees.

## Output format

Present as clearly labeled sections. Flag any violations or warnings prominently. End with a one-line summary: "Membrane healthy" or "N issues found: [list]".

## Arguments

$ARGUMENTS — if "json", output a machine-readable JSON summary instead of prose.
