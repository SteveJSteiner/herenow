## Protocol Header
- **Purpose:** requirements authority for the GitHub-template temporal membrane discipline.
- **Authority:** requirements only.
- **Must contain:** problem statement, goals, non-goals, design principles, acceptance criteria, open issues, and normative requirement statements.
- **Must not contain:** implementation details, symbol sketches, import graphs, module trees, execution order, node breakdown, commit protocol.
- **Update rule:** edit only when requirements change.

## Status
Draft

# Requirements

## Problem statement
Build a repository discipline, distributable through a GitHub template, that uses git itself as the enforcement medium for a temporal membrane architecture. The initialized repository must support distinct temporal roles, enforce ancestry and composition constraints on the present configuration, keep its governing machinery inspectable as source, and remain bootstrappable by a fresh operator without relying on external CI or platform policy.

## Goals
- Distinguish past, future, now, and meta roles inside one repository with different operational affordances.
- Preserve a common-root membrane lineage so ancestry checks are meaningful and mechanically checkable.
- Make the now branch a compositional control surface rather than a payload branch.
- Enforce grounding and monotonicity constraints through git-native mechanisms.
- Keep policy evolution visible in normal history and enforcement legible as source.
- Support fresh initialization from a GitHub template into a sovereign governed repository.

## Non-goals
- Defining implementation language, module layout, import graph, or binary packaging strategy.
- Defining execution order, roadmap nodes, continuation workflow, or commit protocol.
- Requiring automatic upgrade paths from the originating template after initialization.
- Using external CI, GitHub Actions, or social process as the primary enforcement mechanism.
- Treating worktree ergonomics as a load-bearing architectural requirement.

## Design principles
- Use git's own affordances as the medium of enforcement.
- Keep authoritative governance inspectable in tracked source.
- Evaluate consistency atomically on the candidate resulting composition.
- Separate composition governance on `now` from internal governance within submodules.
- Prefer explicit machine-readable declarations over convention or inference.
- Treat bootstrap and bypass behavior as first-class parts of the requirements surface.

## Acceptance criteria
A requirements-complete design satisfies all of the following at minimum:
- A fresh repository generated from the template can be initialized into a common-root membrane topology.
- The initialized now branch can activate governance with a single bootstrap step.
- Composition-changing commits on now are checked for past monotonicity, future grounding, and atomic consistency.
- Bypass cannot silently accumulate and has bounded exposure under the chosen response mechanism.
- The active enforcement machinery can be checked against declared meta state.
- Enforcement authority remains readable as source in history.
- The repository remains sovereign after initialization; no implicit upstream coupling is assumed.

## Open issues
- Whether authoritative enforcement source lives directly on `now` or is carried primarily through `meta` while `now` carries launch/activation content.
- Which immune-response mechanism is chosen once bypass is detected.
- Whether freshness checks for derived artifacts remain heuristic at first or move immediately to content-hash validation.
- Final `.gitmodules` path policy and any naming conventions needed for settlement or role change.
- Whether the initialized repository keeps an explicit visible provenance branch for the pre-init scaffold and how that branch is named.

## Normative requirements

Temporal membrane architecture using git as the enforcement medium.

## R1 — Temporal role differentiation

The system must distinguish four roles for branches within a single repository: past (settled, retained), future (speculative, projected), now (present composition), and meta (operational self-governance). Each role must carry different affordances for what operations are legitimate, what constraints are enforced, and what consequences operations produce.

## R2 — Common origin

All branches must share a common initial commit. No orphan branches. The shared root is contentless — the act of beginning, not the beginning of content. This ensures `merge-base` is always well-defined across any pair of branches and that divergence is always measurable.

## R3 — Now branch: composition without substantive payload

The now branch must contain no substantive payload of its own. Its tree consists exclusively of submodule declarations, enforcement machinery (hooks, launchers, manifest, constraint definitions), bootstrap/provisioning content, and operational metadata. This requirement permits operational content needed to express and activate composition, but it does not permit proofs, application code, manuscripts, datasets, or other domain payloads. Where the authoritative enforcement source itself lives (directly on now or via the meta submodule) remains an open design choice; the requirement is that the now branch carry enough tracked content to activate enforcement without external authority.

## R4 — Past branch: monotonic settlement

Past branches must only advance forward. Once a SHA on a past branch has been pinned by the now branch, neither the SHA nor any of its ancestors may be rewritten without detectable breakage. Settlement accumulates as a structural fact: the longer the now branch has been pinning into a past branch, the more of its history becomes load-bearing.

## R5 — Future branches: grounded speculation

Every future branch must descend from a non-trivial commit on the direct history of a named past branch. The ancestry relationship must be declared and verified. Multiple future branches may exist simultaneously, each grounded at a different point on the past. Futures may be rebased, restarted, or deleted without consequence to other branches. Constraint evaluation ranges over the futures declared in the candidate post-change composition. Removing a future from `.gitmodules` or from the committed composition retires that future from subsequent cross-checks rather than leaving a dangling obligation against historical declarations.

## R6 — Ancestry constraint enforcement

The system must verify, on every composition-changing commit to the now branch, that each future submodule's pinned SHA descends from a commit on the lineage of its declared past submodule. If a past pin advances, all futures naming that past must be rechecked. A commit that would produce an inconsistent configuration must be rejected.

## R7 — Submodule role declaration

Each submodule referenced by the now branch must carry a machine-readable role declaration (past, future, or meta) and, for future-typed submodules, an explicit ancestor-constraint naming the past submodule it must descend from. These declarations must live in tracked content (`.gitmodules` with custom keys) readable by native git config parsing.

## R8 — Atomic consistency

Every commit on the now branch must represent a fully consistent configuration. It must not be possible to advance a past pin, add a future, or change a constraint in a way that leaves the composition in a partially valid state. Cross-constraints (past advancement invalidating futures) must be checked within the same enforcement pass.

## R9 — Self-consistency of operational machinery

The now branch must be able to verify that its currently active enforcement machinery matches the version it declares via its meta submodule pin. Divergence between the active hooks and the pinned meta state is a self-consistency violation that must be detectable and reportable.

## R10 — Enforcement through medium affordance

Constraint enforcement must operate through git's own hook mechanism, not through external CI, platform features, or social convention. The enforcement machinery must be carried as content on the now branch (or in the meta submodule) such that checking out the now branch and configuring `core.hooksPath` is sufficient to activate enforcement. No external authority required.

## R11 — Bypass must be conspicuous and self-limiting

It must not be possible to silently accumulate constraint violations. Any bypass of enforcement (e.g. `--no-verify`) must be detected automatically by non-bypassable hook paths after the violating commit exists, including rewrite-sensitive paths such as `post-rewrite` when history-editing commands are in scope. The design must ensure bounded exposure: under the chosen response mechanism, a bypass yields at most one violating commit before the system either neutralizes the violation or enters a dead-end that prevents normal governed work from continuing until the violation is resolved. The exact immune-response mechanism is a parameterized design choice rather than a requirement-level commitment.

## R12 — Policy evolution as first-class history

Changes to the enforcement rules themselves must be versioned, diffable, and part of the now branch's commit history. The history of the now branch must be readable as a record of both compositional changes (what the present held) and operational changes (how the present governed itself).

## R13 — Source legibility of enforcement

The enforcement logic must be inspectable as source code at every point in the now branch's history. `git log -p` on the now branch must show readable diffs for any change to the enforcement machinery. No opaque binaries in the authoritative representation. Compiled artifacts derived from the enforcement source are caches, not authorities.

## R14 — Worktree coexistence

It must be possible to have simultaneous working surfaces for the now branch, past branches, future branches, and the meta branch, all backed by the same object store and ref namespace. Work on a past branch in a worktree must produce commits immediately referenceable by a now-branch pin update in a separate worktree without push, fetch, or clone operations.

## R15 — Content-as-policy per branch

Each branch must be able to carry its own `.gitattributes`, `.gitignore`, and hook definitions that govern operations on that branch. Policy travels with content. A branch checked out in a worktree or submodule inherits its own policy through its own tracked content, not through external configuration.

## R16 — Submodule independence

Each instantiated submodule must be a fully independent git repository with its own `.git` directory, refs, HEAD, config, and hook namespace. The now branch's hooks govern composition (pin validity). Each submodule's own hooks govern its internal operations. These are separate enforcement domains.

## R17 — Bootstrapping

A fresh checkout of the now branch must be usable with a single bootstrap step. The bootstrap step must configure `core.hooksPath`, build any derived enforcement artifacts from tracked source, and produce a working state in which all subsequent operations are governed. The bootstrap script itself must be tracked content on the now branch. Bootstrap failure semantics must be defined: partial success must either be safely retryable/idempotent or leave an explicit recovery procedure that returns the repository to a known bootstrap boundary.

## R18 — Freshness of derived artifacts

If the enforcement logic is compiled from source, the build cache must be verifiable against the current source state. The hook launcher must detect when the cached binary is stale relative to the tracked source and `Cargo.lock`, and rebuild before executing. The hot path (binary fresh) must not require a toolchain. The cold path (binary stale or missing) must produce a correct binary from tracked source.

## R19 — Template sovereignty and upgrade posture

A repository generated from the GitHub template becomes sovereign after initialization. There is no requirement that an initialized membrane repository be able to pull upstream template evolution automatically. If upgrade support is later added, it must be explicit, inspectable, and compatible with the repository's own history rather than implied by continued linkage to the template source.
