Create a new future branch grounded in a past branch, and register it in the now-branch composition.

## Context

Future branches (`future/<name>`) represent grounded speculation. The grounding constraint requires that the future pin declared in `now` composition is a descendant-or-equal of the past lineage pin also declared in `now` composition. Both pins are read from `now` — not from the current checkout.

The membrane uses bare gitlinks as composition entries. `git submodule add` is the wrong primitive here — it initializes a working tree and creates tracking metadata that conflicts with the membrane's worktree-based model. Use manual `.gitmodules` edits and `git update-index --cacheinfo` only.

## Resolving the now authority surface

All composition reads and writes target `now` directly.

Resolution order:
1. **now worktree exists**: `git worktree list --porcelain | awk '/^worktree/{w=$2} /branch refs\/heads\/now/{print w; exit}'`
2. **Current checkout is now**: `git symbolic-ref --short HEAD` == `now`
3. **Neither**: suggest `/worktrees now` and stop

For reads (resolving pins and checking composition): use `git show now:.gitmodules` and `git rev-parse now:<path>` regardless of now authority mode.

## Arguments

$ARGUMENTS — `<name> [<past-branch>] [<start-commit>]`

- `<name>` — branch name suffix; result is `refs/heads/future/<name>`
- `<past-branch>` — the past branch to ground in (e.g., `past/v1`). If omitted, list registered past entries from `git show now:.gitmodules` and ask.
- `<start-commit>` — where to branch from (default: current tip of `refs/heads/<past-branch>`)

Use lowercase hyphen-separated names: `new-auth`, `refactor-api`, `experiment-xyz`.

## Operation sequence

### 1. Validate preconditions

```
git rev-parse --verify now                              # membrane must be initialized
git show now:.gitmodules | grep "membrane-role = past"  # at least one past entry
git rev-parse --verify refs/heads/<past-branch>         # past branch ref must exist
git show now:.gitmodules | grep "<past-branch>"         # past must be registered on now
git rev-parse --verify refs/heads/future/<name> 2>/dev/null  # must not already exist
```

Abort with explanation if any check fails.

### 2. Resolve the lineage pin from now

```
LINEAGE_PIN=$(git rev-parse now:<past-branch>)
```

If unresolvable, abort: "past branch <past-branch> is not registered in now composition."

### 3. Resolve the start commit

If `<start-commit>` is given:
```
START=$(git rev-parse <start-commit>)
git merge-base --is-ancestor $LINEAGE_PIN $START
```
If the ancestry check fails, abort: "Start commit is not a descendant of the lineage pin `$LINEAGE_PIN`. Future branches must descend from their declared past lineage."

If `<start-commit>` is not given:
```
START=$(git rev-parse refs/heads/<past-branch>)
```

### 4. Create the ref

```
git update-ref refs/heads/future/<name> $START
```

The ref is created first. A ref without a composition entry is safe — enforcement only applies to what is declared in `now` composition.

### 5. Edit `.gitmodules` on now

In the now working directory, append to `.gitmodules`:

```
[submodule "future/<name>"]
	path = future/<name>
	url = .
	membrane-role = future
	membrane-lineage = <past-branch>
```

Stage:
```
git -C <NOW_ROOT> add .gitmodules
```

### 6. Register the gitlink on now

```
git -C <NOW_ROOT> update-index --add --cacheinfo 160000,$START,future/<name>
```

### 7. Commit on now

```
git -C <NOW_ROOT> commit -m "register future/<name> grounded in <past-branch>"
```

If the hook rejects the commit, report its output verbatim.

### 8. Report

- Ref created: `refs/heads/future/<name>` at `<short-start>`
- Grounded in: `<past-branch>` at lineage pin `<short-lineage-pin>`
- Next step: work on `future/<name>`, then `/future-graduate <name>`

## Failure and recovery

**Mutated first**: the ref (`refs/heads/future/<name>`) is created in step 4, before composition changes.

**Partial state that can remain**: ref exists but no composition entry on `now`.

**Detect**:
```
git rev-parse refs/heads/future/<name>           # ref present?
git show now:.gitmodules | grep "future/<name>"  # composition entry present?
```

**Recover** — resume from step 5 (composition was not written):
```
# append the stanza to .gitmodules in the now working directory, then:
git -C <NOW_ROOT> add .gitmodules
git -C <NOW_ROOT> update-index --add --cacheinfo 160000,$START,future/<name>
git -C <NOW_ROOT> commit -m "register future/<name> grounded in <past-branch>"
```

To undo entirely:
```
git update-ref -d refs/heads/future/<name>
```
