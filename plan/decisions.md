# TDD — Temporal Membrane Architecture

## Protocol Header
- **Purpose:** technical design for satisfying `requirements.md`.
- **Authority:** design choices only. Architecture here is provisional direction, not additional requirements.
- **Must contain:** module placement, import graph, symbol sketches, constructive-definition choices, compatibility strategy, tradeoffs.
- **Must not contain:** execution order, active-task instructions, completion history.
- **Update rule:** edit when technical design changes.

## Status
Draft

A git-native system for organizing agent and human work across temporal roles — settled past, speculative future, composed present, and operational meta — using git's own mechanisms as the enforcement medium.

This document records the current technical direction, identifies where it is settled and where it remains genuinely open, and captures the reasoning behind each resolution without adding new requirements.

---

## 0. Design framing

### 0.1 Module placement

Current placement direction is:

- `now` carries composition declarations, hook entrypoints, bootstrap machinery, and any minimal launch surface required to evaluate composition.
- `meta` carries operational self-governance artifacts that may be pinned and advanced like any other governed component.
- `past/*` and `future/*` carry substantive payload.
- The remaining open placement question is whether the authoritative enforcement source lives directly on `now` or is pinned from `meta` and launched by `now` (see §5.2).

### 0.2 Import graph

The current import/dependency direction is intentionally one-way:

- bootstrap provisions the local environment and activates the hook surface;
- hooks call a single enforcement entrypoint rather than embedding branch logic themselves;
- the enforcement entrypoint reads git state, `.gitmodules`, and branch/ref relations;
- domain payload on `past/*` and `future/*` is inspected only through git object/ref structure, not imported as code into enforcement.

This keeps the enforcement surface narrow: branch-role interpretation and ancestry checks depend on repository state, not on executable imports from the governed payload.

### 0.3 Symbol sketches

The design currently assumes a small set of operational concepts, regardless of implementation language:

- **Role descriptor** — a parsed view of one submodule entry and its declared temporal role.
- **Ancestor constraint** — the named past lineage a future claims to descend from.
- **Candidate composition** — the full post-change now-branch configuration being evaluated atomically.
- **Violation record** — a durable description of why a candidate composition failed validation.
- **Meta fingerprint** — the observable relation between active enforcement machinery and declared meta state.

These are symbol sketches, not final API commitments.

### 0.4 Constructive-definition choices

The key constraints are defined constructively in git terms:

- past monotonicity is checked by commit ancestry, not by timestamps or labels;
- future grounding is checked by commit ancestry against a named past lineage;
- cross-constraint evaluation ranges over the resulting candidate composition, not an incremental local diff alone;
- meta self-consistency is checked by comparing active enforcement state against declared meta state, not by trust in operator intent.

### 0.5 Compatibility strategy

Compatibility is currently defined as continuity of external behavior across implementation changes:

- start with shell where possible to reduce bootstrap complexity;
- allow migration to Rust or another compiled implementation once the behavioral surface is stable;
- preserve the same observable hook contract, bootstrap contract, and validation outcomes across that migration;
- treat platform-sensitive heuristics, such as mtime freshness, as provisional unless they survive empirical use.

### 0.6 Tradeoff stance

The design intentionally prefers git-native inspectability and ancestry-grounded checks over simpler multi-repo separation. That buys structural legibility at the cost of unusual submodule ergonomics, stricter bootstrap discipline, and sharper pressure on the now/meta boundary.

## 1. Foundational structure

### 1.1 Single repository, multiple branches

The system is a single git repository. All temporal structure is expressed through branches, submodules, and hooks — not through multiple repositories, external coordination, or platform features.

The central claim is that git's content-addressed store, ref system, and hook mechanism are sufficient to express and enforce a non-trivial temporal organization. This claim is untested at scale and may prove wrong in specific areas (see §9, areas of genuine uncertainty), but it is the design premise.

### 1.2 Common origin

All branches share a single initial commit. This commit is empty — it carries no content. It is the act of beginning, not the beginning of content.

**Decision [D1 — CLOSED]:** Use a shared initial commit, not orphan branches. Orphan branches would disavow common origin. Branching from the empty commit acknowledges it. This ensures `git merge-base` is always well-defined across any pair of branches, that diffing across branches is meaningful, and that merging is structurally available even if rarely used. The branches are differentiations of a common ground, not unrelated timelines.

### 1.3 Four branch roles

The system distinguishes four roles. These are not git constructs — git knows nothing about roles. They are conventions made enforceable through hooks and submodule declarations.

**Past** — Settled, retained work. What has been deposited and audited. Carries substantive content (proofs, code, artifacts). Expected to advance monotonically. Increasingly rigid as external references (pins from the now branch) accumulate.

**Future** — Speculative work. Grounded in the past but not yet settled. Plastic — may be rebased, restarted, abandoned. Multiple futures may coexist, each exploring a different direction from a different point on the past.

**Now** — The present. A composition of references to past and future branches. No substantive content of its own. Each commit on the now branch is a reconfiguration of what the system is currently holding together.

**Meta** — Operational self-governance. Tooling, enforcement source, provisioning scripts. The machinery by which the now branch understands and enforces its own rules.

The four-role distinction is a design choice, not a necessity. A simpler system might have only past and now, or might not distinguish meta from now. The current design reflects a specific judgment that the composition of the present and the governance of that composition are usefully separable concerns.

### 1.4 Branch naming and initialized topology

The initialized repository uses the following branch namespace:

- **`now`** — the composition branch. Singular. The primary working surface.
- **`past/<name>`** — settled-work branches. Each past branch carries its own name under the `past/` namespace.
- **`future/<name>`** — speculative branches. Each future carries its own name under the `future/` namespace.
- **`meta`** — operational self-governance. Singular until a concrete use case for multiple meta branches emerges.
- **`provenance/scaffold`** — the pre-init GitHub template history. Not part of the membrane topology (see §1.5).

**Decision [D24 — CLOSED]:** Branch names use role-based namespaces: `past/`, `future/`, `provenance/`. `now` and `meta` are bare names. This makes role visible in `git branch` output and ref listings without requiring extra metadata lookup. The namespace convention applies to branch names in `refs/heads/`; submodule checkout paths on the now branch tree are a separate question (see D6-PATHS, still open).

**Decision [D25 — CLOSED]:** The initialized branch set — what exists immediately after `init` — is `now`, `meta`, and `provenance/scaffold`. Past and future branches are not created at initialization; they are created by the operator when substantive work begins. The initial `.gitmodules` on `now` declares only the `meta` submodule. Past and future submodule entries are added as the operator creates and pins those branches.

### 1.5 Provenance branch

The pre-init scaffold history (the GitHub template's original branch) is retained as `provenance/scaffold`. This branch is visible for inspection but is not part of the temporal membrane topology.

**Decision [D26 — CLOSED]:** Provenance invariants:

1. The provenance branch shares no commit ancestry with membrane branches. Membrane branches descend from a fresh common-root commit created at initialization; the provenance branch descends from the template's original history. These are disjoint commit graphs within the same object store.
2. Enforcement hooks do not traverse, check, or constrain the provenance branch.
3. The provenance branch is not declared as a submodule in `.gitmodules`.
4. R2 (common origin) applies to membrane branches — `now`, `past/*`, `future/*`, `meta` — not to provenance. The provenance branch is outside the system that R2 governs.

The provenance branch exists solely so an operator can inspect how the repository was scaffolded. It is an archaeological record, not a governed participant.

---

## 2. The now branch

### 2.1 Composition without substantive payload

The now branch's tree contains submodule declarations (`.gitmodules`), enforcement hooks/launchers, a bootstrap script, and constraint metadata. It does not contain proofs, application code, manuscripts, datasets, or other substantive domain artifacts.

**Decision [D2 — CLOSED]:** Now is pure composition in the stronger sense of carrying no substantive payload. Operational content required to express and activate composition is permitted on now; domain payload is not. The rationale is structural: if the present had its own substantive payload, it would be just another deposit. The now branch exists as a configuration of acknowledgments — which past state it retains, which future states it entertains. Every commit is an attentional reconfiguration.

The remaining open question is narrower than before: whether the authoritative enforcement source itself lives directly on now or is referenced through the meta submodule. That is a tooling-placement question, not a question about whether operational scaffolding is allowed on now at all (see §5.2).

### 2.2 What a commit on now means

Each commit on the now branch records a change to how the system operates with respect to its constituent branches. This includes:

- Adding or removing a submodule pin (opening or releasing a concern)
- Advancing a pin (acknowledging that work in some other branch has reached a state worth incorporating)
- Changing the enforcement hooks or constraint definitions (revising the rules of composition)
- Changing the meta pin (incorporating new operational tooling)

The history of the now branch is therefore readable as two interleaved records: a record of what the present held at each moment, and a record of how the present governed itself.

### 2.3 Path layout

The now branch's tree after initialization:

```
.now/
  hooks/
    pre-merge-commit
    post-merge
    pre-commit
    post-commit
    post-rewrite
  src/                    # enforcement source — present only if D18 resolves to "on now"
  bin/                    # .gitignore'd compiled cache — present only if D19 resolves to compiled
plan/
  requirements.md
  decisions.md
  roadmap.md
  continuation.md
  completion-log.md
meta/                     # meta submodule checkout (path subject to D6-PATHS for future past/future entries)
.gitmodules               # submodule declarations with custom role keys
.gitignore                # ignores .now/bin/ and other derived artifacts
bootstrap.sh              # single bootstrap entry point
```

The `.now/` directory is the namespace for enforcement machinery: hook launchers, enforcement source (if on now per D18), and derived build artifacts. It is the operational kernel of the now branch. `core.hooksPath` points to `.now/hooks/`.

The `plan/` directory holds all planning and governance documents (see §2.4).

The `meta/` directory is the checkout path for the meta submodule. When past and future submodules are added later, their checkout paths are governed by D6-PATHS (flat vs. hierarchical, still open).

`bootstrap.sh` lives at the now branch root for discoverability — it is the first thing an operator runs after checkout.

**Decision [D3-LAYOUT — CLOSED]:** `.now/` is the enforcement namespace. `plan/` is the planning-file namespace. `bootstrap.sh` is at root. The layout accommodates both D18 outcomes (enforcement source on now vs. in meta) and both D19 outcomes (shell vs. compiled): `.now/src/` and `.now/bin/` appear only when those decisions call for them. Submodule checkout paths for past and future entries remain subject to D6-PATHS.

### 2.4 Planning file placement and document contracts

The five planning documents live on the `now` branch in `plan/`:

| File | Authority | Mutation rule |
|------|-----------|---------------|
| `requirements.md` | Requirements only | Edit only when requirements change |
| `decisions.md` | Design choices only | Edit when technical design changes |
| `roadmap.md` | Sequencing and integration | Edit when sequencing, chunk boundaries, or validation strategy changes |
| `continuation.md` | Current-task execution | Replace when the active task changes; refresh in place while it remains active |
| `completion-log.md` | Transition history | Append-only; one line per material continuation transition |

Each file carries a protocol header specifying its purpose, authority, must-contain/must-not-contain rules, and update discipline. These headers are the file's self-enforcing contract — they define what the file is allowed to hold and when it should be mutated.

**Decision [D27 — CLOSED]:** Planning files live on `now` in `plan/`. They are operational metadata permitted by R3, not domain payload. They describe the project's compositional intent and execution state — properties of the present. Placing them on `now` keeps them directly visible on the primary working surface. Placing them on `meta` was considered but rejected: meta's role is enforcement machinery and tooling, not project management. The planning files are about what the present is doing; meta is about how the present governs itself.

The front-matter contract for each file is stable enough for GT5 to generate starter versions with the correct protocol headers automatically. The initializer creates all five files with protocol headers and minimal starter content.

---

## 3. Submodule architecture

### 3.1 Self-referencing submodules

The now branch's submodules point to branches within the same repository, using a relative self-reference (`url = ./`). This means the now branch composes views of its own repo's branches, not external dependencies.

**Decision [D4 — CLOSED]:** Self-referencing submodules via a relative self-URL. The single-repo structure makes the relationship between base and extension internal to the project's own history. No cross-repo coordination. Pin updates in worktrees reference SHAs in the same object store — no push or fetch required.

**Clarification:** self-reference does not inherently create an infinite recursive loop. Recursion only continues if a checked-out submodule commit itself declares nested submodules that point back into the same graph. Under this discipline, the compositional declarations live on now; pinned commits on past, future, and meta are not expected to carry their own self-referential `.gitmodules`.

**Known hazard:** naive `git clone --recurse-submodules` or recursive submodule update is still an ergonomic footgun. The likely failure mode is redundant self-cloning, confusing tool behavior, or unnecessary bandwidth, not unbounded recursion by default. Bootstrap must therefore handle initialization explicitly with non-recursive or selective initialization, and the repository should carry a visible note warning operators away from naive recursive submodule workflows.

### 3.2 Role declaration

Each submodule carries a machine-readable role in `.gitmodules` using custom keys that git parses but does not act on:

```ini
[submodule "rca0"]
    path = past/rca0
    url = ./
    role = past

[submodule "sls"]
    path = future/sls
    url = ./
    role = future
    ancestor-constraint = rca0

[submodule "tools"]
    path = meta/tools
    url = ./
    role = meta
```

**Decision [D5 — CLOSED]:** Custom keys in `.gitmodules`, read by hooks via `git config --file .gitmodules --get submodule.<n>.role`. Git preserves unrecognized keys without acting on them. No custom file format, no synchronization problem between a separate manifest and `.gitmodules`.

The `ancestor-constraint` key on future submodules names the past submodule from which the future must descend. This is the link that makes the grounding constraint (§4.2) checkable.

**Decision [D6-PATHS — OPEN]:** Whether submodule paths should reflect their role hierarchically (`past/rca0`, `future/sls`) or be flat (`rca0`, `sls`) with roles only in `.gitmodules`. Hierarchical makes role visible in the filesystem and gives hooks a fast path-prefix heuristic. Flat avoids the implication that role is a directory-level property and, more importantly, avoids disruptive path renames if a future later settles into a past. The practical argument now leans flat more strongly than before, but the decision remains open until the initialization and operator workflow are exercised.

### 3.3 Submodule independence

Each instantiated submodule is a fully independent git repository — its own `.git` directory, refs, HEAD, config, hooks. This is git's native submodule behavior, not a design choice. But the consequence is architecturally significant: the now branch's hooks govern composition (which configurations of pins are valid), while each submodule's own hooks govern internal operations. These are separate enforcement domains.

The now branch cannot reach into a submodule and constrain its internal operations through its own hook machinery. It can provision (provide hooks and configuration), and it can detect (verify that a submodule has hooks set up), but it cannot enforce. Enforcement is local to each repository.

**Decision [D7-PROVISIONING — OPEN]:** How the now branch provisions submodule hooks. Options range from centralized (meta carries a setup script that configures every submodule) to decentralized (each content branch carries its own hooks and the now branch simply trusts self-enforcement). Current leaning is decentralized — each content branch carries its own hooks, meta carries a verification script that checks whether submodules are properly configured. But this means the now branch has no guarantee that content branches are actually enforcing their declared constraints.

---

## 4. Constraint enforcement

### 4.1 Monotonic past advancement

When the now branch updates a past-typed submodule pin, the new pin must be a descendant of the old pin. `git merge-base --is-ancestor <old-pin> <new-pin>` is the check. Moving a past pin backward or sideways is rejected.

**Decision [D8 — CLOSED]:** Past pins advance monotonically. Settlement doesn't reverse. The past branch represents retained, auditable work. Allowing the now branch to point backward would mean the present could un-acknowledge something already deposited.

The rigidity of this constraint increases over time. Early in the project, the past has few pins pointing at it and rewriting is cheap (only a few things break). As the now branch accumulates a long history of past-pin references, more of the past's history becomes load-bearing.

### 4.2 Grounded futures

Every future-typed submodule's pinned SHA must descend from a non-trivial commit on the direct history of its declared past submodule. The check uses `git merge-base` to find the fork point and verifies that fork point is an ancestor of the current past pin and is not the empty root commit.

**Decision [D9 — CLOSED]:** Futures must be grounded in a named past. The ancestry constraint is explicit, per-future, and verified on every now-branch commit that changes a future pin. A future that doesn't descend from the past's lineage is ungrounded speculation — not connected to the deposited work.

**Decision [D10 — CLOSED]:** The fork point need not be the current past tip. A future may have been started from an earlier state of past and still be valid. The constraint is "descended from somewhere on past's line," not "descended from the tip." This permits multiple futures at different depths of grounding.

### 4.3 Cross-constraints

When a past pin advances, all futures naming that past via `ancestor-constraint` must be rechecked. If the past has advanced past a future's fork point — if the future's grounding is no longer on the past's current line — the commit is rejected.

This means past and future pins cannot always be updated independently. Advancing the past may require simultaneously re-grounding one or more futures. The now branch's commits are atomically consistent configurations: every pin in a commit satisfies all constraints, or the commit doesn't happen.

**Decision [D11 — CLOSED]:** Atomic consistency enforced at commit time. The constraint checker evaluates the full configuration, not individual pin updates.

### 4.4 Meta self-consistency

The now branch can verify that its currently active enforcement machinery matches the version declared by its meta submodule pin. The simplest check is hash comparison between the active hooks/source and the corresponding files at the meta pin's SHA.

**Decision [D12 — OPEN (mechanism)]:** Self-consistency between active machinery and declared meta is a requirement. The exact verification mechanism (byte-identity of hook files, hash of source tree, or something else) is not yet determined. The concern is that byte-identity may be too rigid (formatting changes, platform line-ending differences) while hash comparison may be too opaque. This needs practical testing.

### 4.5 Multiple past branches

**Decision [D13 — OPEN]:** Whether the architecture supports one past or many. The motivating case is a strength hierarchy: an RCA0 formalization as one past, an arithmetic-level formalization as a separate, stronger past. A future could declare ancestry from either. Multiple pasts introduce a partial order on settlement and increase the complexity of the ancestry constraint. Current leaning is to support it with per-future explicit `ancestor-constraint`, but the first concrete use case (RCA0 + SLS) may not actually require it. This decision should be deferred until the payload demands it.

---

## 5. Enforcement machinery

### 5.1 Hook architecture

Enforcement uses git's hook mechanism. The design relies on two structural facts about git hooks:

1. `--no-verify` bypasses `pre-commit`, `commit-msg`, and `pre-merge-commit`. It does **not** bypass `post-merge`, `post-commit`, `post-checkout`, or `post-rewrite`.

2. `core.hooksPath` allows hooks to be read from a tracked directory rather than `$GIT_DIR/hooks/`, making the hook scripts themselves versioned content.

The enforcement has two layers:

**Gate (bypassable):** `pre-merge-commit` and `pre-commit` check all constraints before the commit is created. If the composition is malformed, the commit is rejected. Under normal operation, no violations occur.

**Immune response detection (non-bypassable):** `post-merge`, `post-commit`, and rewrite-sensitive hooks such as `post-rewrite` run after the commit exists or after history-editing operations complete. If a violation was introduced via `--no-verify` or surfaced through rewrite activity, the post-hook path detects it and hands control to the response mechanism.

**Decision [D14 — CLOSED]:** Two-layer enforcement. Gate + non-bypassable detection. Normal operation hits the gate and never needs the immune-response path. Bypass detection is mandatory, including rewrite-sensitive paths when rebase/amend workflows are permitted.

**Decision [D15 — OPEN]:** What exactly the immune response does once detection fires. The architecture commits to automatic post-event detection and bounded exposure; it does not yet commit to a single corrective mechanism.

Candidate mechanisms under D15:

- **Auto-revert:** A post-event hook immediately creates a revert commit. Strongest response, but reverting inside a post-hook is mechanically unusual and may have edge cases.
- **Tag + refuse-next:** Tag the violation. The next governed operation checks parent and refuses to proceed. Simpler, but a determined operator can keep chaining bypasses, though each violation remains conspicuous.
- **Tag + degrade:** Tag and log. Subsequent operations run in degraded mode with warnings. Softest response.

Current leaning is auto-revert if mechanically sound. This needs empirical testing across git versions and across post-commit, post-merge, and post-rewrite paths.

### 5.2 Where the enforcement source lives

The hooks in the `core.hooksPath` directory are small shell launchers (~3 lines each) that delegate to a compiled binary or interpreted program carrying the real constraint logic.

**Decision [D16 — CLOSED]:** The hook launchers are trivial POSIX shell. Shell is present wherever git is present. The launchers locate the enforcement binary, rebuild if needed, and exec. All real logic is elsewhere.

The authoritative representation of the enforcement logic is source code, not a compiled binary. Any binary is a derived cache.

**Decision [D17 — CLOSED]:** Source is authority, binary is cache. The membrane's legitimacy comes from inspectability. A checked-in binary is opaque to `git diff` and `git log -p`. The most critical content on the now branch must be readable as source diffs. Compiled artifacts go in `.gitignore`'d cache directories.

**Slogan:** Executable at the edge, legible at the core.

**Decision [D18 — OPEN]:** Whether the enforcement source lives on the now branch or in the meta submodule.

If on now: `git log -p` on the now branch directly shows enforcement evolution. Maximum inspectability. No indirection. But the now branch then has content — operational content, but content — which creates tension with the "pure composition" principle (§2.1).

If in meta: Cleaner role separation. Now is purely compositional; meta carries the operational source. But inspecting the current enforcement requires looking at two places — the now branch for which meta version is pinned, and the meta branch for what that version contains.

This is genuinely open. The answer depends on whether "the hooks are part of now's identity" or "the hooks are a tool now consumes." Both readings are defensible. What is no longer open is the requirement boundary: now may carry operational scaffolding, but not substantive domain payload.

### 5.3 Source language

**Decision [D19 — OPEN]:** What language the enforcement logic is written in.

**Shell throughout:** Zero additional dependencies. The constraint checks are expressible as git command pipelines. Viable for a small constraint set. Becomes fragile as the logic requires data structures, error accumulation, cross-constraint checking, and structured error reporting.

**Rust (with Cargo):** Type-safe, good error handling, static binary. `Cargo.lock` gives reproducible builds. Already in the ecosystem. Heavier bootstrap — requires Rust toolchain for first build.

**Python (with or without uv):** Nearly universal, no compilation, fast iteration. Version and environment variance is a real problem. `uv run --script` with shebangs is interesting but adds its own dependency.

The recommendation is to start with shell and migrate when complexity demands it. The shell launchers stay regardless — only the implementation behind them changes. The signal to migrate is when the constraint logic needs testability, data structures, or structured error handling beyond what shell provides gracefully.

### 5.4 Freshness of derived artifacts

If the enforcement logic is compiled from source, the hook launcher must verify the cache is current before executing. The check compares filesystem modification times between the cached binary and the source tree + lockfile. If any source is newer, the launcher rebuilds.

**Decision [D20 — CLOSED]:** Freshness check via mtime comparison for the initial implementation. `cargo build --locked` ensures the lockfile is respected. `--offline` prevents network access once dependencies are cached. The hot path (binary fresh) is a few stat calls with no toolchain involvement.

**Known limitation:** checkout, rebase, stash application, and other history-editing operations can perturb mtimes without meaningful content change, causing spurious rebuilds. This is acceptable for the initial shell-first or early compiled prototype, but if rebuild cost becomes material the design should move to a content-hash-based freshness check.

### 5.5 Bypass cost structure

The architecture produces a specific gradient of escalating cost for increasingly severe violations:

1. **Normal operation** — Free. Hooks check, commit proceeds.
2. **`--no-verify`** — Requires explicit flag and knowledge. Produces one violating commit. Non-bypassable post-hook responds immediately. Violation and response are both permanent in history.
3. **Delete/modify hook file** — Tracked content change. Visible in `git diff`, permanent in branch history, attributable.
4. **Rewrite history** — Force-push. Breaks all downstream pins. Detectable via reflog (~90 day window). Can be blocked by `receive.denyNonFastForwards`.

Each level requires more expensive authority and leaves a more permanent trace. This is not a security boundary — a sufficiently motivated actor can defeat any client-side enforcement. It is a cost structure that makes the default behavior correct, makes violation conspicuous, and makes erasure of the violation record the hardest thing to do.

---

## 6. Worktrees

`git worktree add` creates additional working trees backed by the same repository — same object store, same refs. Different HEAD, different index, different working tree.

The architecture expects simultaneous worktrees for different branch roles:

- **Now worktree:** The composition surface. Pin updates, hook changes. Submodules may or may not be initialized here.
- **Past worktree:** Direct content work. Commits advance the past branch tip in the same object store. Immediately referenceable by the now worktree's pin updates.
- **Future worktree(s):** One per future branch. Independent speculation surfaces.
- **Meta worktree:** Develop enforcement tooling without touching the now branch's active hooks.

Git's one-branch-per-worktree constraint serializes access to each branch. This is correct for past (settlement should not be concurrent) and now (composition should not be concurrent). Multiple futures naturally get multiple worktrees.

The temporal gap between the past worktree's HEAD and the now branch's past-pin is visible as a filesystem-level difference between two directories. The gap is the un-acknowledged work — real, committed, but not yet incorporated into the present.

**Decision [D21 — CLOSED]:** Worktree-per-role as the expected working model. Not required by the architecture — everything works with a single worktree and branch-switching — but the spatial coexistence makes the temporal structure tangible.

---

## 7. Initialization

Initialization transforms a repository generated from the GitHub template into the membrane branch topology. It is a one-time local operation, distinct from bootstrapping (§8), which activates enforcement on an already-initialized repository.

### 7.1 Initializer command

The initializer is `./init.sh`, a POSIX shell script at the repository root. It lives on the pre-init scaffold branch and is consumed once: after initialization, it exists on `provenance/scaffold` but not on `now`.

The normal invocation takes no arguments. The interface reserves `--help` and `--dry-run` for future use without requiring their implementation in the first version.

The initializer is non-interactive: no prompts, deterministic behavior, meaningful exit codes (0 for success or already-initialized, non-zero for failure). This supports both human operators and coding agents running init programmatically.

**Decision [D28 — CLOSED]:** Initializer/bootstrap lifecycle split. Initialization (`./init.sh`) and bootstrapping (`./bootstrap.sh`) are separate commands with separate lifecycles:

- `./init.sh` runs once from the pre-init scaffold branch. It creates the membrane branch topology and finishes by checking out `now`. It is not needed again after successful completion.
- `./bootstrap.sh` runs from the `now` branch. It activates enforcement (sets `core.hooksPath`, builds derived artifacts, initializes submodules per D22). It is idempotent and needed on every fresh checkout.

A second operator who clones an already-initialized repository skips init entirely and runs only `./bootstrap.sh` after checking out `now`. The two commands share no operational dependency beyond init producing the topology that bootstrap expects to find.

### 7.2 Provenance preservation

Initialization never rewrites, squashes, or deletes pre-existing history. Whatever commit lineage existed before initialization is preserved as provenance:

- The pre-init scaffold lineage is recorded as `provenance/scaffold`, a new branch ref pointing at the scaffold tip at the time of initialization.
- If the operator made additional commits on the scaffold branch before running init, those commits remain in the provenance lineage.
- The membrane branches (`now`, `meta`) descend from a fresh common root commit with disjoint ancestry from the provenance lineage (per D26).
- The original branch name (e.g. `main`) is left intact. Init is purely additive — it creates new refs, never modifies or deletes existing ones. The operator may remove the original branch name at their discretion after initialization.

**Decision [D29 — CLOSED]:** Initialization preserves provenance and never rewrites history. The pre-existing scaffold lineage — including any operator commits made before init — is retained as `provenance/scaffold`. Membrane branches are created as a new lineage from a fresh common root. No existing ref is renamed, modified, or deleted by the initializer.

### 7.3 Initialization markers and re-run detection

Initialization is recognized by explicit membrane markers and canonical refs, not by branch-name coincidence alone.

The markers are:

- **`refs/membrane/root`** — points to the empty common root commit from which all membrane branches descend.
- **Canonical membrane branches** — `now` and `meta` both descend from the commit at `refs/membrane/root`.

Re-run detection checks for the membrane markers:

- If `refs/membrane/root` exists and canonical branches descend from it: already initialized. Print a no-op message, exit 0.
- If `refs/membrane/root` exists but some canonical branches are missing or not yet seeded: partial initialization. Resume from the first incomplete step.
- If `refs/membrane/root` does not exist: not yet initialized. Proceed with full initialization.

A branch named `now` that does not descend from the membrane root is not treated as evidence of prior initialization.

**Decision [D30 — CLOSED]:** Initialization is stepwise-idempotent and marker-based. Each step is guarded by a precondition check; if already complete, it is skipped. After full successful completion, re-run detects the initialized state via `refs/membrane/root` and the canonical branch lineage, and exits 0. Detection relies on membrane markers, not on branch-name coincidence.

### 7.4 Initialization steps

The initializer performs the following discrete steps, each independently guarded for idempotence:

1. **Create root ref** — create the empty common root commit and store it as `refs/membrane/root`.
2. **Record provenance** — create `provenance/scaffold` pointing at the current scaffold branch tip.
3. **Create `now`** — branch from the common root.
4. **Create `meta`** — branch from the common root.
5. **Seed `now`** — populate with the canonical skeleton: `.now/hooks/`, `bootstrap.sh`, `.gitmodules` (declaring the `meta` submodule), `.gitignore`.
6. **Seed `meta`** — populate with minimal initial content.
7. **Seed planning files** — create the five planning files in `plan/` on `now` with protocol headers and starter content (per D27).
8. **Checkout `now`** — switch the working tree to the `now` branch.

If any step fails, the operator re-runs `./init.sh`. The script detects which steps are complete via the membrane markers and branch state, and resumes from the first incomplete step. No manual cleanup is required at any failure point.

### 7.5 Scope boundary: local topology only

The initializer defines local Git topology. It does not modify or depend on:

- Remote default branch settings
- Branch protection rules
- GitHub template configuration
- Any hosted platform state

Hosted platform configuration (e.g. changing the GitHub default branch to `now`, setting up branch protections) is a packaging and documentation concern addressed separately, not a responsibility of the initializer.

**Decision [D31 — CLOSED]:** Initialization defines local Git topology only; hosted platform settings are out of scope. `init.sh` operates entirely within the local repository using Git commands. Any hosted platform configuration is handled separately through documentation or admin tooling.

---

## 8. Bootstrapping

A fresh checkout of the now branch requires one setup step:

```sh
./bootstrap.sh
```

This script:

1. Sets `core.hooksPath` to the tracked hooks directory
2. Builds the enforcement binary from source (if source exists and binary is missing/stale)
3. Initializes submodules selectively (not recursively — see §3.1)
4. Optionally creates worktrees for the standard roles

After bootstrap, all subsequent operations are governed. The bootstrap script itself is tracked content on the now branch, versioned and diffable. Bootstrap must be idempotent or leave a clear recovery path if it fails mid-flight; partial configuration that silently leaves the repo half-governed is not acceptable.

**Decision [D22 — CLOSED]:** Single bootstrap entry point. One command, then you're in a governed environment, with retryable or explicit recovery semantics if bootstrap fails.

**Decision [D23 — OPEN]:** Submodule initialization strategy during bootstrap. Full (all roles initialized), selective (only roles needed for current task), or manual (user decides). Current leaning is selective with an interactive prompt, but this depends on the actual workflow patterns that emerge.

---

## 9. Areas of genuine uncertainty

The following are not open decisions awaiting a resolution so much as areas where the design may be wrong in ways we haven't yet discovered.

**Self-referencing submodule ergonomics.** The `url = ./` pattern avoids multi-repo coordination but still cuts against the expectations of naive recursive submodule workflows and some tooling. The risk is operator confusion and redundant self-cloning more than true infinite recursion under the intended discipline. Whether that operational cost is worth the structural benefit is an empirical question. If it proves too friction-laden, the alternative is separate repos with a coordination protocol — which is well-understood but lacks the self-referential character the design is trying to achieve.

**Scale of constraint logic.** The constraint set is currently small: monotonic past, grounded futures, meta self-consistency. If domain-specific constraints accumulate (strength bounds per past branch, content-type constraints per future, inter-future coherence conditions), the enforcement logic may outgrow whatever language it starts in. The shell-to-Rust migration path is designed to handle this, but the threshold is unknown.

**Post-hook revert mechanics.** The immune-response layer relies on `post-merge` and `post-commit` being able to meaningfully respond to violations. Whether auto-revert inside a post-hook is reliable across git versions, merge types, and edge cases is untested. If it isn't reliable, the design falls back to tag-and-refuse, which is weaker.

**Agent interaction.** The architecture is designed for a world where coding agents (Claude Code, Codex) are the primary operators within submodules. Whether agents naturally respect the hook-governed workflow — or whether they attempt `--no-verify` by default, or modify hook files, or otherwise interact badly with the enforcement layer — depends on agent behavior that may change.

**The now branch as bottleneck.** All composition changes serialize through the now branch. If multiple humans or agents want to update pins concurrently, they must coordinate on the now branch. Git's merge mechanics handle this for content branches, but the now branch's constraint-checking hooks may reject merges that are individually valid but jointly inconsistent. Whether this creates a practical bottleneck depends on the pace of composition changes.

---

## Decision log

| ID | Status | §  | Summary |
|----|--------|----|---------|
| D1 | CLOSED | 1.2 | Common root, not orphan branches |
| D2 | CLOSED | 2.1 | Now is pure composition, no substantive content |
| D3-LAYOUT | CLOSED | 2.3 | Path layout on the now branch |
| D4 | CLOSED | 3.1 | Self-referencing submodules via relative self-URL |
| D5 | CLOSED | 3.2 | Role declaration via custom .gitmodules keys |
| D6-PATHS | OPEN | 3.2 | Hierarchical vs. flat submodule paths |
| D7-PROVISIONING | OPEN | 3.3 | How now provisions submodule hooks |
| D8 | CLOSED | 4.1 | Monotonic past advancement |
| D9 | CLOSED | 4.2 | Futures must descend from named past |
| D10 | CLOSED | 4.2 | Fork point need not be current past tip |
| D11 | CLOSED | 4.3 | Atomic consistency of configurations |
| D12 | OPEN | 4.4 | Meta self-consistency check mechanism |
| D13 | OPEN | 4.5 | Single vs. multiple past branches |
| D14 | CLOSED | 5.1 | Two-layer enforcement: gate + non-bypassable detection |
| D15 | OPEN | 5.1 | Immune response behavior |
| D16 | CLOSED | 5.2 | Hook launchers in POSIX shell |
| D17 | CLOSED | 5.2 | Source is authority, binary is cache |
| D18 | OPEN | 5.2 | Enforcement source on now vs. in meta |
| D19 | OPEN | 5.3 | Source language for enforcement logic |
| D20 | CLOSED | 5.4 | Freshness check via mtime comparison (initial heuristic) |
| D21 | CLOSED | 6 | Worktree-per-role as expected working model |
| D22 | CLOSED | 8 | Single bootstrap entry point with recovery semantics |
| D23 | OPEN | 8 | Submodule initialization strategy |
| D24 | CLOSED | 1.4 | Role-namespaced branch naming (past/, future/, provenance/) |
| D25 | CLOSED | 1.4 | Initialized set: now, meta, provenance/scaffold only |
| D26 | CLOSED | 1.5 | Provenance branch invariants — outside membrane topology |
| D27 | CLOSED | 2.4 | Planning files on now in plan/ |
| D28 | CLOSED | 7.1 | Initializer/bootstrap lifecycle split |
| D29 | CLOSED | 7.2 | Initialization preserves provenance, never rewrites history |
| D30 | CLOSED | 7.3 | Stepwise-idempotent, marker-based initialization |
| D31 | CLOSED | 7.5 | Init defines local Git topology only; platform settings out of scope |
