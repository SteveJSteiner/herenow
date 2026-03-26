# Temporal Membrane — Operator Reference

This is a GitHub template for creating a git repository with enforced temporal
structure. The repository distinguishes four branch roles — past, future, now,
and meta — and enforces structural constraints on the `now` branch through git
hooks. No external CI or platform policy is required.

To be precise about what that means: when the enforcement source is active, a
commit to `now` that pins a `past` branch to an ancestor of its current pin
will be rejected before the commit lands (`pre-commit`), and if it sneaks in
anyway (`--no-verify`), it will be automatically reverted on the next governed
operation (`post-commit`). The constraint logic is POSIX shell, readable in
`.now/src/`, with no external dependencies.

---

## Contents

1. [Getting started](#getting-started)
2. [What init.sh creates](#what-initsh-creates)
3. [What bootstrap.sh does](#what-bootstrapsh-does)
4. [The enforcement gap](#the-enforcement-gap)
5. [Branch roles](#branch-roles)
6. [The enforcement chain](#the-enforcement-chain)
7. [What each check verifies](#what-each-check-verifies)
8. [Violation responses](#violation-responses)
9. [Bypass detection](#bypass-detection)
10. [Adding past and future branches](#adding-past-and-future-branches)
11. [Worktree provisioning](#worktree-provisioning)
12. [Known limitations and discrepancies](#known-limitations-and-discrepancies)

---

## Getting started

### Requirements

- POSIX shell (`/bin/sh`)
- Git 2.38 or later (required by `bootstrap.sh` for the `protocol.file.allow` flag)

### Step 1: Generate a repository from the template

Use GitHub's **"Use this template"** button, or:

```sh
gh repo create my-repo --template <this-template> --clone
cd my-repo
```

At this point you have the scaffold. The branch `main` (or whichever branch
HEAD is on) contains `init.sh`, `bootstrap.sh` (embedded inside `init.sh`),
the full enforcement source in `.now/src/`, real enforcement hooks in
`.now/hooks/`, and test suites in `.now/tests/` and `test/`. No membrane
topology exists yet.

### Step 2: Initialize the membrane

```sh
./init.sh
```

`init.sh` is idempotent and non-interactive. It creates the membrane topology
using git plumbing commands (no working-tree writes) and ends by checking out
the `now` branch. See [What init.sh creates](#what-initsh-creates) for the
full list of refs and commits it produces.

### Step 3: Bootstrap governance

```sh
./bootstrap.sh
```

`bootstrap.sh` is embedded in `init.sh` as a heredoc and seeded onto the `now`
branch during step 5 of init. Running it activates `core.hooksPath`,
initializes the `meta` submodule, and verifies both. See
[What bootstrap.sh does](#what-bootstrapsh-does) for details.

### What you have after init + bootstrap

You are on the `now` branch. `core.hooksPath` points to `.now/hooks/`. There
is a `meta/` directory containing the initialized meta submodule. The five
hooks in `.now/hooks/` are executable.

**Read the next section before assuming those hooks enforce anything.** They
don't — not yet.

---

## What init.sh creates

`init.sh` runs eight steps, each guarded by an idempotency check:

| Step | What it creates | Ref or path |
|------|----------------|-------------|
| 1 | Shared empty root commit | `refs/membrane/root` |
| 2 | Snapshot of the pre-init state | `refs/heads/provenance/scaffold` |
| 3 | The `now` branch, pointing at the root | `refs/heads/now` |
| 4 | The `meta` branch, pointing at the root | `refs/heads/meta` |
| 5 | Hook stubs, `bootstrap.sh`, `.gitmodules`, `.gitignore` onto `now` | commit on `refs/heads/now` |
| 6 | A README onto `meta` | commit on `refs/heads/meta` |
| 7 | Planning files and the meta gitlink onto `now` | commit on `refs/heads/now` |
| 8 | Checkout of `now` | working tree |

All branches descend from `refs/membrane/root`. This shared common ancestor
makes `git merge-base` well-defined across all branches — past, future, now,
and meta all share the same empty origin.

`init.sh` is purely additive. It never modifies or deletes existing refs.

### What step 5 actually seeds onto `now`

The hook files created in step 5 are stubs. Every one of the five hooks is
identical:

```sh
#!/bin/sh
# Stub launcher — enforcement logic added in later roadmap nodes.
exit 0
```

The enforcement source (`.now/src/`) is **not** copied to the `now` branch by
`init.sh`. Only `.now/hooks/` (with stubs) and supporting files are added.

### The `.gitmodules` seeded onto `now`

The only submodule declared at init time is `meta`:

```ini
[submodule "meta"]
    path = meta
    url = ./
    role = meta
```

The `url = ./` pattern is self-referencing: the `meta` submodule points at the
same repository, pinned to the `meta` branch tip.

---

## What bootstrap.sh does

`bootstrap.sh` is seeded onto the `now` branch by `init.sh` step 5. After
checking out `now`, run it from the repository root:

```sh
./bootstrap.sh
```

Bootstrap has three steps:

**Step 1 — Activate hooks.** Sets `core.hooksPath = .now/hooks` and makes
every file in `.now/hooks/` executable.

**Step 2 — Enforcement detection.** Checks whether `.now/src/` exists and
prints a notice if it does. The bootstrap comment says explicitly: "No source
exists yet (D18/D19 open). When `.now/src/` appears, build here." On a freshly
initialized `now` branch, `.now/src/` does not exist, so this step is a no-op.

**Step 3 — Meta submodule.** Runs `git submodule init meta`, overrides the
submodule URL to point at the local repository (`git rev-parse --show-toplevel`),
and runs `git -c protocol.file.allow=always submodule update meta`. This is why
Git 2.38+ is required: the `protocol.file.allow` flag was introduced then to
permit local file-protocol submodule URLs.

Bootstrap verifies that `core.hooksPath` is set correctly and that `meta/` is
non-empty before exiting. It is safe to re-run.

---

## The enforcement gap

This is the most important thing to understand about the setup.

After `init.sh` and `bootstrap.sh`, the hooks in `.now/hooks/` are stubs that
exit 0. They enforce nothing. `core.hooksPath` points at them, so git will call
them — and they will do nothing.

The full enforcement source lives on `provenance/scaffold` (which points at the
same commit as `main` before init). It contains:

- `.now/src/immune-response.sh` — the shared response library sourced by all post-hooks
- `.now/src/check-composition.sh` — the orchestrator that runs all four checks
- `.now/src/validate-gitmodules.sh` — static schema validation
- `.now/src/check-past-monotonicity.sh` — past pin ancestry check
- `.now/src/check-future-grounding.sh` — future pin ancestry check
- `.now/src/check-meta-consistency.sh` — enforcement manifest verification
- `.now/hooks/pre-commit` — the real pre-commit hook
- `.now/hooks/post-commit`, `post-merge`, `post-rewrite`, `pre-merge-commit` — the real post-hooks

After `git checkout now`, these files are not present in the working tree. The
`now` branch was seeded only with stub hooks. To activate real enforcement, the
operator must propagate the enforcement source from `provenance/scaffold` to the
`now` branch. There is no automated step for this — the KNOWN-LIMITATIONS file
describes this as manual work and notes that "there is no automated sync
mechanism."

The rest of this document describes the enforcement source as it exists on
`provenance/scaffold`. When you read about what a hook "does," that refers to
the real hook on the scaffold, not the stub on `now`.

---

## Branch roles

After init, these branches exist:

| Branch | Role | What it contains |
|--------|------|-----------------|
| `now` | Present composition | Gitlink pins, stub hooks, `bootstrap.sh`, planning stubs, meta submodule |
| `meta` | Self-governance | A README; intended to carry enforcement tooling when populated |
| `provenance/scaffold` | Provenance | Snapshot of the template state before init — contains the full enforcement source |
| `refs/membrane/root` | Shared origin | An empty commit; the common ancestor of all branches |

The operator creates `past/*` and `future/*` branches manually. There is no
tooling to create them — see [Adding past and future branches](#adding-past-and-future-branches).

---

## The enforcement chain

When the real enforcement source is active, every hook follows the same chain:

```
hook script
  → sources .now/src/immune-response.sh
    → checks recursion guard (MEMBRANE_REVERTING file)
    → calls check-composition.sh via $EVALUATOR
      → runs validate-gitmodules.sh
      → runs check-past-monotonicity.sh
      → runs check-future-grounding.sh
      → runs check-meta-consistency.sh
    → takes response action (block / auto-revert / tag)
```

`check-composition.sh` is the orchestrator. It runs all four checks regardless
of whether earlier ones fail, so a single commit can surface multiple violations
at once. It exits 1 if any check fails, 0 only if all pass.

The hooks set `SRC_DIR` to `.now/src/` relative to their own location, then
source `immune-response.sh`. That file sets `EVALUATOR="$SRC_DIR/check-composition.sh"`.

---

## What each check verifies

### Schema validation — `validate-gitmodules.sh`

Parses `.gitmodules` and enforces six static rules on every submodule entry:

- **Rule 1**: `role` must exist and be one of `past`, `future`, or `meta`.
- **Rule 2**: Submodules with `role = future` must have an `ancestor-constraint`
  key naming an existing submodule with `role = past`.
- **Rule 3**: Submodules with `role = past` or `role = meta` must not have an
  `ancestor-constraint` key.
- **Rule 4**: `url` must be `./`.
- **Rule 5**: `path` must equal the submodule name.
- **Rule 6**: No two submodules may share the same `path`.

The canonical key names are `role` and `ancestor-constraint`. No other names
work. `validate-gitmodules.sh` reads `submodule.<name>.role` and
`submodule.<name>.ancestor-constraint` literally. If you write `membrane-role`
or any other name, the validator will report a missing `role` key and reject
the entry.

### Past monotonicity — `check-past-monotonicity.sh`

For every submodule with `role = past`, reads the gitlink SHA from HEAD (`git
ls-tree HEAD -- <path>`) and from the index (`git ls-files --stage -- <path>`),
then runs:

```sh
git merge-base --is-ancestor "$old_pin" "$new_pin"
```

If this fails — meaning the new pin is not a descendant of the old pin — the
check reports a violation and exits 1. Moving a past pin backward, or to a
divergent commit, is a violation. First-time pins (no old pin in HEAD) are
allowed.

### Future grounding — `check-future-grounding.sh`

For every submodule with `role = future`, reads the `ancestor-constraint` key
to identify the declared past lineage, then reads both the future pin and the
past pin from the index. It runs:

```sh
git merge-base "$future_pin" "$past_pin"
```

The fork point must exist and must not be the root commit. A fork point at the
root commit means the future and past share only the empty origin — trivial
shared history — which is not a real lineage relationship. The check exits 1
if no non-trivial common ancestor exists.

### Meta self-consistency — `check-meta-consistency.sh`

Reads the meta submodule's gitlink SHA from the index, then reads an
`enforcement-manifest` file from that meta commit:

```sh
git show "$meta_pin:enforcement-manifest"
```

The manifest is a list of lines in the format `<blob-hash> <file-path>`. For
each line, the check runs `git hash-object <file-path>` against the working
tree and compares the result to the declared hash. Any mismatch is a violation.
An empty manifest is also a violation.

This means: to pass the meta-consistency check, the `meta` branch must have an
`enforcement-manifest` at its tip, the manifest must be non-empty, and every
file listed in it must exist in the working tree with the exact blob hash
declared. Populating this manifest is part of the operator's setup work.

---

## Violation responses

The three hooks respond differently to violations because the situations call
for different responses.

### `pre-commit` and `pre-merge-commit` — block

These hooks run before the commit is written. If `check-composition.sh` exits
non-zero, the hook exits non-zero and git aborts the commit. The error output
shows which checks failed. Nothing is written to history.

```sh
# From .now/hooks/pre-commit:
sh "$EVALUATOR" "$REPO_ROOT/.gitmodules"
```

The output flows directly to the user so they see which check failed.

### `post-commit` — auto-revert

This hook runs after a commit has been written. If the composition check fails,
`membrane_auto_revert` is called. It:

1. Sets the recursion guard (`$GIT_DIR/MEMBRANE_REVERTING`) to prevent
   re-entry when the revert itself fires `post-commit`.
2. Runs `git revert --no-edit HEAD` (or `git revert --no-edit -m 1 HEAD` for
   merge commits).
3. Sets the coordination marker (`$GIT_DIR/MEMBRANE_VIOLATION_HANDLED`) so
   that `post-rewrite` knows the violation was already handled.
4. Clears the recursion guard.

The result: the violating commit exists in history, followed immediately by its
revert. The working tree and HEAD are left in a valid state.

### `post-merge` — auto-revert

Same behavior as `post-commit` for non-squash merges. Fast-forward merges
get a plain revert; no-ff merges get `-m 1`. Squash merges fire `post-commit`
when the user actually commits.

Conflict-resolved merges also fire `post-commit` (not `post-merge`) because
git considers the commit as having been made by the user.

### `post-rewrite` — tag-and-refuse-next (for rebase)

After a rebase completes, `post-rewrite` receives `"rebase"` as its argument.
If the resulting state is a violation, the hook does not auto-revert — rebases
may have placed the violating commit mid-history, not at HEAD, making a clean
revert fragile. Instead it calls `membrane_tag_violation`:

```sh
git tag "$_tag" HEAD
```

where `_tag` is `membrane/violation/<short-sha>`. The tag marks the violation
durably. The next governed operation will encounter the tagged state.

For `git commit --amend`, `post-rewrite` receives `"amend"`. It first checks
the `MEMBRANE_VIOLATION_HANDLED` marker — if `post-commit` already handled the
violation, it clears the marker and exits. If the marker is absent, it runs the
constraint evaluator itself and auto-reverts if needed.

---

## Bypass detection

`git commit --no-verify` bypasses `pre-commit` and `pre-merge-commit`. It
cannot bypass `post-commit`.

If a violating commit is made with `--no-verify`, `post-commit` fires and
runs the constraint evaluator. The violation is detected and `membrane_auto_revert`
is called. The working tree ends up at a valid state, with the violation and
its revert both in history.

This is documented in the README as "bypass detection": post-hooks cannot be
skipped by `--no-verify`. The recursion guard in `membrane_guard_active` (which
checks for the `$GIT_DIR/MEMBRANE_REVERTING` file) prevents the auto-revert
from triggering another auto-revert.

Note: immune response is local only. It cannot prevent a `git push --force` of
violated state to a remote. See [Known limitations](#known-limitations-and-discrepancies).

---

## Adding past and future branches

There is no tooling to create past or future branches. The operator does this
manually.

### Creating a past branch

```sh
# Create the branch from wherever you want past history to start.
git branch past/my-work <some-commit>
```

Then add the submodule entry to `.gitmodules` on the `now` branch. The exact
key names are critical — the validator reads `role` and `ancestor-constraint`
literally:

```ini
[submodule "past/my-work"]
    path = past/my-work
    url = ./
    role = past
```

Then stage the gitlink (the submodule pointer to the commit you want to pin):

```sh
git update-index --add --cacheinfo 160000,<commit-sha>,past/my-work
```

Commit. If enforcement source is active, `pre-commit` will run the full
constraint suite before accepting the commit.

### Creating a future branch

A future branch must share non-trivial history with an existing past branch —
meaning they must have a common ancestor that is not the empty root commit. The
simplest way is to branch from the past branch:

```sh
git branch future/my-speculation past/my-work
```

Add the submodule entry. A future branch **must** have an `ancestor-constraint`
key naming the past submodule it descends from:

```ini
[submodule "future/my-speculation"]
    path = future/my-speculation
    url = ./
    role = future
    ancestor-constraint = past/my-work
```

The `ancestor-constraint` value must match the name of an existing submodule
with `role = past`. Using any other string will fail `validate-gitmodules.sh`
rule 2.

Stage the gitlink and commit. If the future pin does not share a non-trivial
common ancestor with the named past pin, `check-future-grounding.sh` will
reject the commit.

### Advancing pins

To advance a past pin (record that the past branch has moved forward):

```sh
# On your past branch, make the new commits.
# Then, on now:
git update-index --add --cacheinfo 160000,<new-commit-sha>,past/my-work
git commit -m "Advance past/my-work"
```

If the new SHA is not a descendant of the old pin, `check-past-monotonicity.sh`
will reject the commit.

---

## Worktree provisioning

`.now/src/provision-worktrees.sh` creates git worktrees at `wt/<branch-name>`
for each branch declared in `.gitmodules`, plus `now`. It is idempotent and
optional — enforcement works without worktrees. This is a convenience for
operators who want each branch checked out simultaneously.

Run it from the `now` branch after bootstrap:

```sh
sh .now/src/provision-worktrees.sh
```

It reads `.gitmodules` to discover branches, skips the currently checked-out
branch (since the root already serves as its worktree), and calls `git worktree
add wt/<name> <branch>` for each one. Missing branches are skipped with a
notice.

---

## Known limitations and discrepancies

### Discrepancy: KNOWN-LIMITATIONS describes stubs as functional

`KNOWN-LIMITATIONS.md` states: "init.sh seeds the `now` branch with stub hooks
and copies enforcement source from the scaffold. After initialization, the hooks
on `now` are functional."

This is not accurate. `init.sh` seeds the `now` branch with stub hooks that
`exit 0`. It does not copy the enforcement source. `bootstrap.sh` step 2 says
explicitly: "No source exists yet (D18/D19 open). When `.now/src/` appears,
build here." After init + bootstrap, the hooks on `now` do nothing. The
enforcement source on `provenance/scaffold` is not active until it is propagated
to the `now` branch, and there is no automated step for this.

### Enforcement is local only

The hooks run via `core.hooksPath`. There is no CI integration. If
`core.hooksPath` is overridden by the operator or by tooling (e.g., an IDE),
enforcement stops silently. The immune response cannot prevent a `git push
--force` of violated state to a remote.

### No past/future branch tooling

The operator creates and wires past and future branches manually. This includes
editing `.gitmodules`, staging gitlinks, and understanding which key names the
validator accepts. There is no command to do this automatically.

### Meta branch requires manual setup

The `meta` branch is initialized with only a README. For the meta-consistency
check to pass, an `enforcement-manifest` must be committed to the `meta` branch,
listing each enforcement file and its expected blob hash. Populating this
manifest is not automated.

### Single past branch tested; multiple past untested

Multiple simultaneous past branches may work but have not been tested. From
KNOWN-LIMITATIONS: "Single past works; multiple past is untested."

### Self-referencing submodule assumes single-remote workflow

The `url = ./` pattern in `.gitmodules` resolves to the local repository. Forks,
multiple remotes, or submodule URL rewriting have not been tested and may break
`bootstrap.sh`'s submodule initialization. From KNOWN-LIMITATIONS: "Multi-remote
or fork workflows are untested."

### No Windows support

All scripts assume POSIX shell. Windows (cmd, PowerShell without WSL) has not
been tested.

### Concurrent operators must coordinate on `now`

All composition changes go through `now`. There is no mechanism for concurrent
operators other than standard git merge mechanics, which the constraint-checking
hooks may reject even for individually valid changes.

---

## Test coverage

The repository includes test suites in `test/` and `.now/tests/`:

| Suite | Location | What it covers |
|-------|----------|----------------|
| GT7 | `test/gt7/` | `validate-gitmodules.sh` — schema rules against fixture files |
| GT8a | `test/gt8a/` | `check-past-monotonicity.sh` — monotonicity checks with real git history |
| GT8b | `test/gt8b/` | `check-future-grounding.sh` — grounding checks with real git history |
| GT8c | `test/gt8c/` | `check-composition.sh` — atomic cross-check orchestrator |
| GT12 | `test/gt12/` | `provision-worktrees.sh` — worktree creation, idempotence, edge cases |
| GT13 | `test/gt13/` | End-to-end smoke test: init → enforcement → bootstrap → compositions |
| GT15 | `test/gt15/` | Fresh-repo acceptance: template generation to governed membrane |
| — | `.now/tests/test-immune-response.sh` | All immune-response hook paths (revert, amend, merge, rebase) |
| — | `.now/tests/test-meta-consistency.sh` | Meta self-consistency check |

KNOWN-LIMITATIONS reports 162 assertions across these suites. Tests do not
cover multi-remote scenarios, non-POSIX platforms, git below 2.38, or
concurrent operator workflows.
