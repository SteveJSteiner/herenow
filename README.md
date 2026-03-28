# Temporal Membrane — Operator Reference

This is a GitHub template for creating a git repository with enforced temporal
structure. The repository distinguishes four branch roles — past, future, now,
and meta — and enforces structural constraints on the `now` branch through git
hooks. No external CI or platform policy is required.

To be precise about what that means: when the enforcement source is active, a
commit to `now` that pins a `past` branch to an ancestor of its current pin
will be rejected before the commit lands (`pre-commit`), and if it sneaks in
anyway (`--no-verify`), it will be automatically reverted on the next governed
operation (`post-commit`). The constraint logic lives in `.now/src/` — plain
POSIX shell, no external dependencies, readable in one sitting.

The repository has three layers. The enforcement substrate (hooks, checkers,
immune response) is the bottom layer and the subject of most of this document.
Above it, operator documentation in `.now/docs/` provides reference-grade
procedure guides for governed operations. On top, the stance layer installs
a working vocabulary and act-layer commands for use with a coding agent. Each
layer is optional upward: the enforcement substrate works without the stance
layer, and the operator docs are useful without installing any vocabulary.

---

## Contents

1. [Getting started](#getting-started)
2. [What init.sh creates](#what-initsh-creates)
3. [What bootstrap.sh does](#what-bootstrapsh-does)
4. [Where the enforcement source lives](#where-the-enforcement-source-lives)
5. [Operator documentation](#operator-documentation)
6. [Command surface](#command-surface)
7. [Agent runtime contract](#agent-runtime-contract)
8. [Branch roles](#branch-roles)
9. [The enforcement chain](#the-enforcement-chain)
10. [What each check verifies](#what-each-check-verifies)
11. [Violation responses](#violation-responses)
12. [Bypass detection](#bypass-detection)
13. [Adding past and future branches](#adding-past-and-future-branches)
14. [Worktree provisioning](#worktree-provisioning)
15. [Known limitations and discrepancies](#known-limitations-and-discrepancies)

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
HEAD is on) contains `init.sh`, the full enforcement source in `.now/src/`,
real enforcement hooks in `.now/hooks/`, operator docs in `.now/docs/`, and
test suites in `.now/tests/` and `test/`. No membrane topology exists yet.

### Step 2: Initialize the membrane

```sh
./init.sh
```

`init.sh` is idempotent and non-interactive. It creates the membrane topology
using git plumbing commands (no working-tree writes) and ends by checking out
the `now` branch. Step 5 of init reads the enforcement source, operator docs,
agent contract, and the fixed `/install-stance` command directly from the
scaffold's HEAD tree and commits them onto `now` — no manual copy step required.
See [What init.sh creates](#what-initsh-creates) for the full list of refs and
commits it produces.

### Step 3: Bootstrap governance

```sh
./bootstrap.sh
```

`bootstrap.sh` is seeded onto the `now` branch by `init.sh` step 5. Running it
activates `core.hooksPath`, initializes the `meta` submodule, and verifies
both. See [What bootstrap.sh does](#what-bootstrapsh-does) for details.

### What you have after init + bootstrap

You are on the `now` branch. `core.hooksPath` points to `.now/hooks/`. The
hooks in `.now/hooks/` are the real enforcement hooks sourced from the scaffold.
`.now/src/` contains the constraint evaluators, operator helpers, and install
machinery. `.now/docs/` contains reference-grade operator procedure docs. The
`meta/` submodule is initialized. `CLAUDE.md` is the agent runtime contract.
The first governed commit will succeed: `init.sh` step 6 seeds an
`enforcement-manifest` on `meta` so the meta-consistency check passes out of
the box.

At this point the enforcement substrate is fully operational. The stance layer
is not yet installed — `meta/stance/vocabulary.toml` exists as an unfilled
skeleton (keys present with empty values). To install a working vocabulary and
act-layer slash commands, see step 4.

### Step 4: Install the stance layer (optional)

Edit the vocabulary manifest on meta:

```sh
$EDITOR meta/stance/vocabulary.toml
```

Fill in the `[stance]` section (title, description, and four noun names) and
the `[commands]` section (six verb names for the act-layer commands). Then run
the installer:

```sh
sh .now/src/install-stance.sh
```

The installer validates the vocabulary, commits it on `meta` via
`commit-to-meta.sh`, renders `STANCE.md` and six act-layer slash commands from
governed templates, stamps a managed import block into `CLAUDE.md`, verifies
command-surface minimality, and commits now-side artifacts. See
`INSTALL-STANCE.md` for the full flow and recovery instructions.

### Optional: provision worktrees

If you want each branch checked out simultaneously in its own directory:

```sh
sh .now/src/provision-worktrees.sh
```

This creates `wt/<branch>/` for each branch declared in `.gitmodules` (using
the submodule/branch name). It is idempotent and optional — enforcement works
without worktrees. See [Worktree provisioning](#worktree-provisioning) for
details.

---

## What init.sh creates

`init.sh` runs eight steps, each guarded by an idempotency check:

| Step | What it creates | Ref or path |
|------|----------------|-------------|
| 1 | Shared empty root commit | `refs/membrane/root` |
| 2 | Snapshot of the pre-init state | `refs/heads/provenance/scaffold` |
| 3 | The `now` branch, pointing at the root | `refs/heads/now` |
| 4 | The `meta` branch, pointing at the root | `refs/heads/meta` |
| 5 | Enforcement hooks (`.now/hooks/`), enforcement source (`.now/src/`), operator docs (`.now/docs/`), `CLAUDE.md`, `INSTALL-STANCE.md`, `.claude/commands/install-stance.md`, `bootstrap.sh`, `.gitmodules`, `.gitignore` onto `now` | commit on `refs/heads/now` |
| 6 | README, `enforcement-manifest`, and stance templates (`stance/vocabulary.toml`, `stance/STANCE.md.template`, `stance/commands/*.md.template`) onto `meta` | commit on `refs/heads/meta` |
| 7 | Planning files and the meta gitlink onto `now` | commit on `refs/heads/now` |
| 8 | Checkout of `now` | working tree |

All branches descend from `refs/membrane/root`. This shared common ancestor
makes `git merge-base` well-defined across all branches — past, future, now,
and meta all share the same empty origin.

`init.sh` is purely additive. It never modifies or deletes existing refs.

### What step 5 seeds onto `now`

Step 5 reads the enforcement source directly from the scaffold's HEAD tree
using `git ls-tree -r HEAD -- .now/hooks/ .now/src/`. The blobs are already in
git's object store from the scaffold commit, so no file copies are needed —
just index entries pointing at the existing objects. Both the hooks in
`.now/hooks/` and the evaluators in `.now/src/` are committed onto the `now`
branch with their original modes and content.

Step 5 also seeds these additional artifacts:

- From the scaffold's HEAD tree (with inline fallbacks):
  - `.now/docs/` — nine operator procedure docs (see [Operator documentation](#operator-documentation))
  - `.claude/commands/install-stance.md` — the fixed slash command for stance installation
  - `CLAUDE.md` — agent runtime contract (see [Agent runtime contract](#agent-runtime-contract))
  - `INSTALL-STANCE.md` — stance install reference for humans
- Generated from embedded templates in `init.sh` (not read from HEAD):
  - `bootstrap.sh` — governance activator (embedded in `init.sh` as a heredoc)
  - `.gitmodules` — declares only the `meta` submodule at init time
  - `.gitignore`

Each HEAD-sourced artifact is read from the scaffold's HEAD tree if present,
with an inline fallback if the scaffold lacks it. The generated artifacts are
always written from embedded templates in `init.sh`.

### What step 6 seeds onto `meta`

Step 6 creates the meta branch's initial content:

- `README.md` — meta branch description
- `enforcement-manifest` — auto-generated from the files seeded onto `now` in
  step 5, listing `<blob-hash> <file-path>` for every file in `.now/hooks/`
  and `.now/src/`. `check-meta-consistency.sh` reads this manifest on every
  governed commit and compares each listed file against the working tree.
- `stance/vocabulary.toml` — unfilled vocabulary skeleton for the stance layer
  (keys present with empty values).
  The operator fills this after bootstrap and before running `install-stance.sh`.
- `stance/STANCE.md.template` — template for the generated `STANCE.md` file.
- `stance/commands/*.md.template` — six templates for the act-layer slash
  commands (`show`, `explore`, `integrate`, `finish`, `change-rules`, `save`).

Because the enforcement manifest is generated from the files that step 5 just
committed, the meta-consistency check passes on the first governed commit
without any manual setup.

### The `.gitmodules` seeded onto `now`

The only submodule declared at init time is `meta`:

```ini
[submodule "meta"]
    path = meta
    url = ./
    role = meta
```

The `url = ./` pattern makes this a self-referencing submodule: `meta` pins a
branch from the same repository. This is the most confusing part of the setup.
The key insight is that git treats a submodule as a pointer to a specific commit
object — the fact that it lives in the same repository is exactly what lets
`bootstrap.sh` initialize it locally without a remote. `bootstrap.sh` overrides
the URL to the local repo path before running `git submodule update`.

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

**Step 2 — Verify enforcement source.** Confirms that `.now/src/` is present.
If it is absent, bootstrap fails with a recovery message. On a correctly
initialized `now` branch (after `init.sh` has run), `.now/src/` is always
present.

**Step 3 — Meta submodule.** Runs `git submodule init meta`, overrides the
submodule URL to point at the local repository (`git rev-parse --show-toplevel`),
and runs `git -c protocol.file.allow=always submodule update meta`. This is why
Git 2.38+ is required: the `protocol.file.allow` flag was introduced then to
permit local file-protocol submodule URLs.

Bootstrap verifies that `core.hooksPath` is set correctly and that `meta/` is
non-empty before exiting. It is safe to re-run.

---

## Where the enforcement source lives

The enforcement source on `provenance/scaffold` contains:

- `.now/src/immune-response.sh` — the shared response library sourced by all post-hooks
- `.now/src/check-composition.sh` — the orchestrator that runs all four checks
- `.now/src/validate-gitmodules.sh` — static schema validation
- `.now/src/check-past-monotonicity.sh` — past pin ancestry check
- `.now/src/check-future-grounding.sh` — future pin ancestry check
- `.now/src/check-meta-consistency.sh` — enforcement manifest verification
- `.now/src/update-manifest.sh` — regenerates the enforcement-manifest on meta after enforcement source changes
- `.now/src/commit-to-meta.sh` — canonical helper for meta commits with gitlink staging on `now`
- `.now/src/install-stance.sh` — stance layer installer (TOML parse, template render, command-surface verification)
- `.now/src/provision-worktrees.sh` — optional worktree provisioner
- `.now/src/create-past.sh`, `create-future.sh`, `advance-past.sh`, `graduate-future.sh` — operator helpers for branch and pin management
- `.now/hooks/pre-commit`, `pre-merge-commit` — the pre-hooks
- `.now/hooks/post-commit`, `post-merge`, `post-rewrite` — the post-hooks

`init.sh` step 5 reads these files directly from the scaffold's HEAD tree (via
`git ls-tree`) and commits them onto the `now` branch. After init and bootstrap,
these files are present in the working tree and `core.hooksPath` points at
`.now/hooks/`.

`init.sh` step 6 also generates an `enforcement-manifest` on the `meta` branch.
The manifest lists every file in `.now/hooks/` and `.now/src/` with its blob
hash. `check-meta-consistency.sh` reads this manifest on every governed commit
and compares each listed file against the working tree. Because the manifest is
generated from the files that step 5 just committed, the check passes on the
first governed commit without any manual setup.

If you update enforcement source files — for example by pulling changes from an
upstream template into `.now/` — run `update-manifest.sh` afterward to keep the
meta manifest consistent:

```sh
# copy or patch the updated files into .now/hooks/ and .now/src/ however you like
sh .now/src/update-manifest.sh
git commit -m "Update enforcement source"
```

`update-manifest.sh` reads the current working-tree files in `.now/hooks/` and
`.now/src/`, creates a new commit on `meta` with a matching manifest, and stages
both the updated meta gitlink and the enforcement files it just manifested. The
staging is atomic: manifest and source land together in the index. Because the
pre-commit hook reads the meta pin from the index, the new manifest is in place
before the constraint check runs — so the commit succeeds without any manual
plumbing.

---

## Operator documentation

`.now/docs/` contains reference-grade procedure docs for governed operations.
These are seeded onto `now` by `init.sh` step 5 and describe the mechanism of
each operation in enough detail for a new operator or coding agent to execute
it without guessing.

| Document | What it covers |
|----------|---------------|
| `init-bootstrap-first-commit.md` | Full path from scaffold to first governed commit |
| `now-commit.md` | Generic governed commit flow on `now` |
| `modify-enforcement-source.md` | Editing `.now/hooks/` or `.now/src/` with manifest alignment |
| `membrane-status.md` | Read-only state classification and governance health |
| `create-past.md` | Creating a new `past/*` branch and pinning it |
| `create-future.md` | Creating a new `future/*` branch with ancestor constraint |
| `advance-past.md` | Advancing an existing past pin |
| `graduate-future.md` | Graduating a future into its declared past |
| `commands-register.md` | Prose quality and structural skeleton for command docs |

Every procedure doc follows the skeleton defined in `commands-register.md`:
when the command applies, truth sources, preconditions, steps, verification,
failure protocol, and evidence to report.

These docs live in `.now/docs/` (not in `.claude/commands/`) because they are
reference material, not slash commands. They ship with the enforcement source
and are always available regardless of whether the stance layer is installed.

---

## Command surface

The slash command surface in `.claude/commands/` has two tiers.

**Fixed tier:** `install-stance.md` is seeded by `init.sh` step 5 and is always
present. It drives `install-stance.sh` — the only mechanism for populating the
generated tier.

**Generated tier:** After running `install-stance.sh`, six act-layer commands
appear in `.claude/commands/`, named according to `meta/stance/vocabulary.toml`.
These are rendered from templates on meta (`stance/commands/*.md.template`) and
tracked by `.claude/commands/.stance-generated`, which lists the generated file
paths. The installer rejects unexpected markdown files in `.claude/commands/` —
only `install-stance.md` and the generated commands recorded in
`.stance-generated` are permitted. Unexpected non-markdown files produce a
warning but do not block installation.

The generated commands follow the same structural skeleton as the operator docs
(when to apply, truth sources, preconditions, steps, verification, failure
protocol, evidence to report), but their vocabulary is domain-specific: the four
stance nouns and six act verbs come from the vocabulary manifest, not from the
enforcement substrate.

To reinstall or update the stance vocabulary, edit
`meta/stance/vocabulary.toml` and rerun `sh .now/src/install-stance.sh`. The
installer cleans the previous generated commands, renders new ones from current
templates, and reverifies the command surface before committing.

---

## Agent runtime contract

`CLAUDE.md` is the durable runtime layer for Claude Code in this repository. It
establishes truth precedence (source > tests > docs > planning > agent prose),
an operating rule for write operations, and a grounded vocabulary table binding
membrane terms to specific files, scripts, and checkers.

When the stance layer is installed, `install-stance.sh` stamps a managed import
block into `CLAUDE.md` that references `@STANCE.md`. This makes the working
vocabulary available to the agent at runtime without duplicating it.
`CLAUDE.md` describes the enforcement substrate and truth precedence;
`STANCE.md` defines the working vocabulary and act-layer interpretation. The two
files are complementary, not overlapping.

---

## Branch roles

After init, these branches exist:

| Branch | Role | What it contains |
|--------|------|-----------------|
| `now` | Present composition | Gitlink pins, enforcement hooks (`.now/hooks/`), enforcement source (`.now/src/`), operator docs (`.now/docs/`), `CLAUDE.md`, `INSTALL-STANCE.md`, `.claude/commands/install-stance.md`, `bootstrap.sh`, planning stubs, meta submodule |
| `meta` | Self-governance | A README, an `enforcement-manifest`, and stance templates (`stance/vocabulary.toml`, `stance/STANCE.md.template`, `stance/commands/*.md.template`) |
| `provenance/scaffold` | Provenance | Snapshot of the template state before init — contains the full enforcement source |
| `refs/membrane/root` | Shared origin | An empty commit; the common ancestor of all branches |

The operator creates `past/*` and `future/*` branches using the helper scripts
in `.now/src/` — see [Adding past and future branches](#adding-past-and-future-branches).

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
declared. `init.sh` step 6 generates this manifest automatically from the files
seeded in step 5, so the check passes on the first governed commit with no setup
beyond `init.sh` and `bootstrap.sh`.

---

## Violation responses

The hooks respond differently to violations because the situations call
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

The reason this works: post-hooks cannot be skipped by `--no-verify`. The
recursion guard in `membrane_guard_active` (which checks for the
`$GIT_DIR/MEMBRANE_REVERTING` file) prevents the auto-revert from triggering
another auto-revert.

Note: immune response is local only. It cannot prevent a `git push --force` of
violated state to a remote. See [Known limitations](#known-limitations-and-discrepancies).

---

## Adding past and future branches

Four helper scripts in `.now/src/` handle the git plumbing. Each one stages
changes and tells you what to commit; the `pre-commit` hook validates the result
before it lands.

### Creating a past branch

```sh
sh .now/src/create-past.sh my-work <some-commit>
git commit -m "Add past/my-work"
```

`create-past.sh` creates the `past/my-work` branch at `<some-commit>` (or HEAD
if omitted), adds the `[submodule "past/my-work"]` entry to `.gitmodules` with
the correct keys (`path`, `url`, `role = past`), and stages the gitlink. The
validator checks `role` and `ancestor-constraint` literally — using any other
key name will fail rule 1 or rule 2 of `validate-gitmodules.sh`.

### Creating a future branch

A future branch must share non-trivial history with its declared past — a common
ancestor that is not the empty membrane root. Branching from the past tip (the
default) satisfies this automatically:

```sh
sh .now/src/create-future.sh my-speculation past/my-work
git commit -m "Add future/my-speculation"
```

Supply a third argument to start from a specific commit instead of the past tip.
`create-future.sh` writes the `ancestor-constraint = past/my-work` key for you.
If the future pin has no non-trivial common ancestor with the declared past pin,
`check-future-grounding.sh` will reject the commit.

### Advancing a past pin

When commits land on a past branch and you want `now` to record the advance:

```sh
sh .now/src/advance-past.sh past/my-work <new-commit>
git commit -m "Advance past/my-work"
```

If the new commit is not a descendant of the current pin, `check-past-monotonicity.sh`
will reject the commit.

### Graduating a future into its past

When work on a future branch is ready to settle, advance the past pin to the new
tip and remove the future from the composition atomically:

```sh
sh .now/src/graduate-future.sh future/my-speculation <new-past-commit>
git commit -m "Graduate future/my-speculation into past/my-work"
```

`graduate-future.sh` reads `ancestor-constraint` from `.gitmodules` to identify
the past submodule, advances its pin, removes the future's gitlink and
`.gitmodules` entry, and stages everything. The past monotonicity check still
runs — `<new-past-commit>` must descend from the current past pin.

---

## Worktree provisioning

`.now/src/provision-worktrees.sh` creates git worktrees at `wt/<branch>`
for each branch declared in `.gitmodules`, plus `now`. It is idempotent and
optional — enforcement works without worktrees. This is a convenience for
operators who want each branch checked out simultaneously.

Run it from the `now` branch after bootstrap:

```sh
sh .now/src/provision-worktrees.sh
```

It reads `.gitmodules` to discover branches, skips the currently checked-out
branch (since the root already serves as its worktree), and calls `git worktree
add wt/<branch> <branch>` for each one. Missing branches are skipped with a
notice.

---

## Known limitations and discrepancies

### No automated upstream sync

`init.sh` seeds the `now` branch with enforcement source from the scaffold, and
seeds an `enforcement-manifest` on `meta` listing each file's blob hash. If the
source is later updated — for example by pulling changes from an upstream
template — the operator copies the new files into `.now/` and then runs
`sh .now/src/update-manifest.sh` to regenerate the manifest and advance the
meta pin. What is not automated is discovering or fetching the upstream changes
themselves; there is no `git pull`-style mechanism for template updates.

### Enforcement is local only

The hooks run via `core.hooksPath`. There is no CI integration. If
`core.hooksPath` is overridden by the operator or by tooling (e.g., an IDE),
enforcement stops silently. The immune response cannot prevent a `git push
--force` of violated state to a remote.

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

### Stance TOML parser is minimal

`install-stance.sh` parses `vocabulary.toml` with POSIX shell and awk. It
handles quoted string values, inline comments, and section headers, but does
not support multi-line strings, arrays, inline tables, or the full TOML spec.
Vocabulary values must be double-quoted strings on single lines.

### Single vocabulary per repository

The stance layer supports one vocabulary manifest (`stance/vocabulary.toml`) and
one set of act-layer commands. There is no mechanism for multiple concurrent
vocabularies or per-branch stance configurations.

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
| GT13 | `test/gt13/` | End-to-end smoke test: init → enforcement → bootstrap → compositions → update-manifest |
| GT15 | `test/gt15/` | Fresh-repo acceptance: template generation to governed membrane |
| GT16 | `test/gt16/` | Stance install: happy path, duplicate managed-block collapse, unexpected-file rejection, invalid index path rejection |
| — | `.now/tests/test-immune-response.sh` | All immune-response hook paths (revert, amend, merge, rebase) |
| — | `.now/tests/test-meta-consistency.sh` | Meta self-consistency check |

Tests do not cover multi-remote scenarios, non-POSIX platforms, git below 2.38,
or concurrent operator workflows.
