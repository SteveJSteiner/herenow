Show the current state of the temporal membrane.

## Context

The `now` branch is the sole authority for composition state. All composition reads come from `now` — not from the current checkout.

Composition state is derived from two sources on `now`:
- `.gitmodules` — role declarations (`membrane-role`, `membrane-lineage` keys)
- gitlinks (the index tree entries) — the pinned commits for each registered branch

Branch inventory is reported separately from composition inventory.

## Resolving the now authority surface (read-only)

All composition reads use ref-aware git commands regardless of the current checkout:

```
git show now:.gitmodules                          # read .gitmodules from now
git ls-tree now                                   # list gitlink entries on now
git rev-parse now:<path>                          # resolve a specific gitlink on now
```

If `now` does not exist, report "Membrane not initialized" and stop.

## What to do

### 1. Branch inventory

Run `git branch -a` and group results by temporal role:
- `now`
- `meta`
- `provenance/*`
- `past/*`
- `future/*`
- (unrecognized branches listed separately)

### 2. Composition inventory

Read from `now` using ref-aware commands:

```
git show now:.gitmodules
git ls-tree now
```

For each entry in `.gitmodules` on `now`, extract:
- `submodule.<name>.membrane-role` (required)
- `submodule.<name>.membrane-lineage` (required for futures)
- The pinned commit: `git rev-parse now:<path>`

### 3. Past entry status

For each `membrane-role = past` entry, determine one of three states:

| State | Condition | Severity |
|---|---|---|
| **pin matches tip** | `git rev-parse now:<path>` == `git rev-parse refs/heads/<path>` | healthy |
| **pin lags tip** | pin is ancestor of tip (`git merge-base --is-ancestor <pin> <tip>` succeeds, pin ≠ tip) | warning |
| **pin invalid** | pin commit is not readable, or branch ref does not exist | violation |

Pin lag is normal. It means the past branch has advanced further than the composition currently declares. It is not corruption.

### 4. Future entry status

For each `membrane-role = future` entry, determine one of three states:

| State | Condition | Severity |
|---|---|---|
| **valid grounding** | `git merge-base --is-ancestor <lineage-pin> <future-pin>` succeeds | healthy |
| **invalid grounding** | future pin does not descend from the declared lineage pin | violation |
| **unknown grounding** | lineage pin or future pin is unresolvable (ref missing or unreachable) | warning |

Where `<lineage-pin>` is derived from the composition on `now` for the named `membrane-lineage` entry.

### 5. Enforcement status

```
git config core.hooksPath
```

- If set to `.now/hooks/`: enforcement active
- If unset or different: enforcement not active (warning)
- Also check whether `.now/src/check-composition.sh` exists and is executable in the now worktree (if present) or via `git show now:.now/src/check-composition.sh 2>/dev/null`

### 6. Meta self-consistency

If `meta` is registered in composition: read its gitlink from `now` and compare to `git rev-parse refs/heads/meta`. Report lag or mismatch.

### 7. Worktrees

Run `git worktree list --porcelain`. For each membrane role found in composition, show whether a worktree exists for it. Separate "missing worktree" from "invalid composition" — the former is informational, the latter is a violation.

## Output format

Emit four sections:

**BRANCH INVENTORY** — list by role
**COMPOSITION** — table: name | role | pin | status
**ENFORCEMENT** — hooksPath, validator present
**WORKTREES** — role | path | present/missing

End with a severity summary on one line:
- `Membrane healthy` — no warnings or violations
- `N warning(s): [list]` — warnings present, no violations
- `N violation(s): [list]` — at least one violation

## Arguments

$ARGUMENTS — if `json`, emit a machine-readable JSON object with keys: `branches`, `composition`, `enforcement`, `worktrees`, `summary`.
