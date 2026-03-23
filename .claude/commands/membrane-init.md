Initialize the temporal membrane in the current repository.

## Context

A membrane repo requires two steps before it is governed:

1. `./init.sh` — creates the branch topology (`refs/membrane/root`, `now`, `meta`, `provenance/scaffold`) from the scaffold checkout
2. `./bootstrap.sh` — activates enforcement on `now` (sets `core.hooksPath` to `.now/hooks/`, initializes the meta submodule, verifies the governed state)

The canonical composition validator lives at `.now/src/check-composition.sh` once bootstrap completes.

These scripts are idempotent. Re-running either is safe.

## Arguments

$ARGUMENTS — optional mode:
- (empty) — detect state and run whatever step is needed next, pausing between steps to report
- `full` or `bootstrap` — run both `init.sh` and `bootstrap.sh` in sequence without pausing

## What to do

### Step 1: assess current state

Run:
```
git branch -a
git config core.hooksPath
git rev-parse --verify now 2>/dev/null && echo "now exists" || echo "now missing"
```

Determine which of four states applies:
- **A** — `now` branch does not exist: membrane not yet initialized
- **B** — `now` branch exists, `core.hooksPath` is not `.now/hooks/`: initialized but not bootstrapped
- **C** — `now` branch exists, `core.hooksPath` is `.now/hooks/`, `.now/src/check-composition.sh` exists and is executable: fully governed
- **D** — partial or unexpected state: report exactly what was found and stop

### Step 2: act on state

**State A — run init:**
- Confirm `init.sh` is present: `ls init.sh`
- Run `./init.sh`
- Capture and report its output
- If `$ARGUMENTS` is `full` or `bootstrap`, continue to state B handling without pausing

**State B — run bootstrap:**
- Confirm `bootstrap.sh` is present in the now worktree or the current checkout: `ls bootstrap.sh`
- Run `./bootstrap.sh`
- Capture and report its output

**State C — already governed:**
- Report the current state without re-running anything
- Show: branches present (grouped by role), `core.hooksPath` value, whether `.now/src/check-composition.sh` exists

**State D — unexpected state:**
- Report exactly what was found
- Do not attempt to repair automatically
- Tell the operator which files or branches are in an unexpected condition

### Step 3: report results

After any successful action, report:
- Which branches now exist, grouped by role: `now`, `meta`, `provenance/*`, `past/*`, `future/*`
- `core.hooksPath` value
- Whether `.now/src/check-composition.sh` is present and executable
- The next suggested command (`/past-create` to register the first past branch)
