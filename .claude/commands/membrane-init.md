Initialize the temporal membrane in the current repository.

## Context

This repository uses the Temporal Membrane template. Before a repo is governed, it needs two steps:
1. `./init.sh` — creates the branch topology (`now`, `meta`, `provenance/scaffold`, `refs/membrane/root`)
2. `./bootstrap.sh` — activates enforcement (sets `core.hooksPath`, initializes the meta submodule, verifies readiness)

## What to do

1. Check the current state: run `git branch -a` and `git log --oneline -5` to understand where we are.
2. Determine whether the membrane has been initialized by checking if the `now` branch exists.
3. If not yet initialized:
   - Confirm `init.sh` exists in the current directory.
   - Run `./init.sh` and report what it created.
   - If arguments `$ARGUMENTS` include "bootstrap" or "full", also run `./bootstrap.sh`.
4. If the `now` branch already exists but `bootstrap.sh` hasn't run (check `git config core.hooksPath`):
   - Ensure we are on the `now` branch.
   - Run `./bootstrap.sh` and report results.
5. If fully initialized, report the current state: branches present, hooksPath value, meta submodule status.

## After initialization

Report:
- Which branches were created
- The `core.hooksPath` value
- Whether enforcement is active
- The next step the operator should take (e.g., "Create your first past branch with /past-create")

## Arguments

$ARGUMENTS — if "full" or "bootstrap", run both init and bootstrap in sequence without pausing.
