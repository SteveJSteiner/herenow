Create a new past branch and register it in the now-branch composition.

## Context

Past branches (`past/<name>`) represent settled, monotonically-advancing history. A past branch has two independent representations:

1. **The ref** — `refs/heads/past/<name>`, the actual git branch
2. **The composition entry** — a gitlink and `.gitmodules` stanza on `now`

Both must be created. The composition entry is the authoritative record; the ref is what other branches descend from.

The membrane uses bare gitlinks as composition entries and manages working presence through worktrees. `git submodule add` is the wrong primitive here — it initializes a working tree and creates tracking metadata that conflicts with the membrane's worktree-based model. Use manual `.gitmodules` edits and `git update-index --cacheinfo` only.

## Resolving the now authority surface

All composition writes target `now` directly. Branch switching in the operator's current worktree is not the default.

Resolution order:
1. **now worktree exists**: find it with `git worktree list --porcelain | awk '/^worktree/{w=$2} /branch refs\/heads\/now/{print w; exit}'`. All file edits and index operations run in that directory.
2. **Current checkout is now**: `git symbolic-ref --short HEAD` == `now`. Use the current working directory.
3. **Neither**: reads use `git show now:<path>`. Writes require a now worktree — suggest running `/worktrees now` to provision one, and stop.

## Arguments

$ARGUMENTS — `<name> [<start-commit>]`

- `<name>` — branch name suffix; result is `refs/heads/past/<name>`
- `<start-commit>` — commit to use as initial pin (default: tip of `now`, or ask)

If no arguments are given, ask for both. Use lowercase hyphen-separated names: `v1`, `feature-auth`, `2024-q1`.

## Operation sequence

Execute in this order:

### 1. Validate preconditions

```
git rev-parse --verify now          # membrane must be initialized
git rev-parse --verify refs/heads/past/<name> 2>/dev/null  # must not already exist
git cat-file -t <start-commit>      # commit must be readable
```

Abort with explanation if any check fails.

### 2. Create the ref

```
git update-ref refs/heads/past/<name> <start-commit>
```

The ref is created first. A ref without a composition entry is safe — the membrane only enforces what is declared in `now` composition.

### 3. Edit `.gitmodules` on now

In the now working directory (resolved above), append to `.gitmodules`:

```
[submodule "past/<name>"]
	path = past/<name>
	url = .
	membrane-role = past
```

Stage the file:
```
git -C <NOW_ROOT> add .gitmodules
```

### 4. Register the gitlink on now

```
git -C <NOW_ROOT> update-index --add --cacheinfo 160000,<start-commit>,past/<name>
```

### 5. Commit on now

```
git -C <NOW_ROOT> commit -m "register past/<name> at <short-commit>"
```

The pre-commit hook (`.now/hooks/pre-commit`) will run the canonical validator. If it rejects the commit, report the hook output verbatim.

### 6. Report

- Ref created: `refs/heads/past/<name>` at `<start-commit>`
- Composition entry registered on `now`
- Next step: `/past-advance past/<name> <new-commit>` when ready to advance the pin

## Failure and recovery

**Mutated first**: the ref (`refs/heads/past/<name>`) is created in step 2, before composition changes.

**Partial state that can remain**: ref exists but no composition entry on `now`.

**Detect**:
```
git rev-parse refs/heads/past/<name>          # ref present?
# composition entry committed on now? (stanza-keyed check)
git show now:.gitmodules | awk -v name='past/<name>' \
  '$0 == "[submodule \"" name "\"]" {found=1} END{exit !found}'
```

**Recover** — resume from step 3 (composition was not written):
```
cat $NOW_ROOT/.gitmodules   # inspect current on-disk state
# append the stanza, then:
git -C <NOW_ROOT> add .gitmodules
git -C <NOW_ROOT> update-index --add --cacheinfo 160000,<start-commit>,past/<name>
git -C <NOW_ROOT> commit -m "register past/<name> at <start-commit>"
```

To undo entirely (if the ref was created but you want to abort):
```
git update-ref -d refs/heads/past/<name>
```
