Create a new past branch and register it in the now-branch composition.

## Context

Past branches (`past/<name>`) represent settled, monotonically-advancing history. They are:
- Declared as submodules in `.gitmodules` on the `now` branch with `membrane-role = past`
- Pinned to a specific commit (the current settled tip)
- Only allowed to advance forward — never backward

A past branch must exist as an actual git branch AND be registered in `.gitmodules` on `now`.

## Arguments

$ARGUMENTS — `<name> [<start-commit>]`

- `<name>` — the branch name suffix (result: `past/<name>`)
- `<start-commit>` — the commit to pin as the initial tip (default: current HEAD)

If no arguments are given, ask the user for the branch name and starting commit.

## What to do

1. **Validate preconditions**:
   - Confirm we have an initialized membrane (`now` branch exists, `core.hooksPath` is set).
   - Confirm there is no existing branch named `past/<name>`.
   - Confirm the start commit exists: `git cat-file -t <start-commit>`.

2. **Create the past branch**:
   - `git branch past/<name> <start-commit>`

3. **Register in `.gitmodules`** (must be done on the `now` branch):
   - Switch to or ensure we are on `now`.
   - Add a submodule entry to `.gitmodules`:
     ```
     [submodule "past/<name>"]
         path = past/<name>
         url = .
         membrane-role = past
     ```
   - Run `git submodule absorbgitdirs` if needed, or simply record the pin via `git update-index --add --cacheinfo 160000,<commit>,past/<name>`.
   - Alternatively, use `git submodule add --name "past/<name>" . past/<name>` with `protocol.file.allow=always`.

4. **Commit the registration** to `now`:
   - Stage `.gitmodules` and the new submodule entry.
   - Commit with message: `register past branch: past/<name> at <short-commit>`

5. **Report**:
   - Branch created at commit
   - `.gitmodules` entry added
   - Remind the operator: "Advance this branch with /past-advance past/<name> <new-commit>"

## Naming conventions

- Use lowercase, hyphen-separated names: `past/v1`, `past/feature-auth`, `past/2024-q1`
- Avoid slashes within the name itself
