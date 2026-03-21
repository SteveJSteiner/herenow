# Roadmap — GitHub Template Temporal Membrane

## Protocol Header
- **Purpose:** execution sequencing for satisfying `requirements.md` and `decisions.md` in small, auditable chunks.
- **Authority:** sequencing and integration strategy only.
- **Must contain:** work chunks, dependencies, output files, validation gates, stress tests, audit hooks, exit criteria.
- **Must not contain:** new requirements, retrospective completion history, commit logs, prose replacing `requirements.md` or `decisions.md`.
- **Update rule:** edit when sequencing, chunk boundaries, file targets, or validation strategy changes.

## Status
Draft

## Sequencing scope

This roadmap is the execution-layer companion to `requirements.md` and `decisions.md`. It sequences design closure, implementation, validation, and packaging in coding-agent-sized chunks. It does not introduce new requirements or restate technical design beyond what is needed to define dependency order, deliverable boundaries, and validation strategy.

## Node conventions

- **Kinds**
  - **Q** — resolve an open design question and update design docs/roadmap.
  - **C** — implement and validate a capability against explicit acceptance criteria.
  - **H** — harden, package, or demonstrate an already implemented spine.
- **Acceptance rule**
  - Every node must end with one of:
    1. accepted completion,
    2. rejected design path with documented reason,
    3. explicit split into child nodes with narrowed acceptance.
- **Validation rule**
  - Code nodes should prefer executable checks (`git` commands, shell tests, fixture repos, smoke scripts) over prose-only claims.
- **Per-node fields**
  - Each node should specify: work chunk, dependencies, output files, validation gates, stress tests or audit hooks where applicable, and exit criteria.
  - If a node proves too large, it must split before implementation drift is hidden inside prose.

## DAG overview

```text
GT0 -> GT1
GT0 -> GT2

GT1 -> GT3
GT1 -> GT4
GT1 -> GT5

GT2 -> GT3
GT2 -> GT14

GT3 -> GT5
GT3 -> GT6
GT3 -> GT12

GT4 -> GT7
GT6 -> GT7

GT7 -> GT8a
GT7 -> GT8b

GT8a -> GT8c
GT8b -> GT8c

GT8c -> GT9

GT9 -> GT10
GT8c -> GT11

GT10 -> GT13
GT11 -> GT13
GT12 -> GT13

GT13 -> GT14
GT13 -> GT15
GT14 -> GT15

GT15 -> GT16
```

## Nodes

### GT0 — Delivery mechanism closure
- **Kind:** Q
- **Depends on:** none
- **Goal:** Decide the relationship between the GitHub template repo and the final membrane repo topology.
- **Deliverables:**
  - design update in `decisions.md`
  - roadmap update if this changes downstream assumptions
  - explicit initializer contract
  - explicit provenance policy for the scaffold branch
- **Acceptance:**
  - The pre-init scaffold history is retained visibly as provenance.
  - It is not part of the governed membrane topology.
  - Initialization creates a new common-root membrane lineage alongside that provenance lineage.
- **Status note:** Resolved in roadmap preamble; keep this node only as a recorded closure if you want it reflected in completion history. Otherwise mark it completed immediately when the planning files are created.

### GT1 — Canonical skeleton and document contracts
- **Kind:** Q
- **Depends on:** GT0
- **Goal:** Define the canonical repository layout produced after initialization, including the roles of `roadmap.md`, `continuation.md`, and `completion-log.md`.
- **Deliverables:**
  - path layout
  - front matter contract for the three planning files
  - explicit statement of which branch each planning file lives on
  - naming policy for past/future/now/meta/provenance branches
- **Acceptance:**
  - A single canonical layout exists and is reflected in design docs.
  - The planning-document contract is concrete enough to generate starter files automatically.

### GT2 — Initializer UX and idempotence contract
- **Kind:** Q
- **Depends on:** GT0
- **Goal:** Specify the user-facing init entry point and its idempotence/recovery model.
- **Questions to resolve:**
  - `./init.sh`, `just init`, `cargo run -p ...`, or other?
  - May init rewrite local history?
  - What happens if init partially succeeds?
  - Is re-running init supported?
- **Deliverables:**
  - CLI contract
  - recovery semantics
  - failure-mode notes
- **Acceptance:**
  - Clear command-level contract suitable for implementation without hidden product decisions.

### GT3 — Create common-root membrane topology in a generated repo
- **Kind:** C
- **Depends on:** GT1, GT2
- **Goal:** Implement the initializer step that creates the real membrane branch topology with a contentless common root.
- **Scope:**
  - create empty common root commit
  - create `now`, `meta`, and `provenance/scaffold` branches (per D25: past and future branches are not created at init)
  - rename/move the pre-init template branch to `provenance/scaffold` (per D26: disjoint ancestry from membrane branches)
  - place the canonical now-branch skeleton (per D3-LAYOUT) and minimal meta content on their respective branches
  - initial `.gitmodules` declares only the `meta` submodule
- **Acceptance:**
  - A fresh repo created from the template can be initialized locally into the canonical branch topology with one command.
  - `git merge-base` across any pair of membrane branches (`now`, `meta`) resolves to the common root.
  - `provenance/scaffold` shares no commit ancestry with membrane branches.
  - Re-running init either no-ops safely or fails with a deliberate, documented message.

### GT4 — Canonical `.gitmodules` schema and path policy
- **Kind:** Q
- **Depends on:** GT1
- **Goal:** Close the remaining schema questions around submodule naming, flat vs hierarchical paths, and required custom keys.
- **Deliverables:**
  - settled `.gitmodules` examples
  - required keys by role
  - path policy decision
- **Acceptance:**
  - The schema is concrete enough that parser and validators can be implemented without guesswork.

### GT5 — Generate starter planning files and front matter
- **Kind:** C
- **Depends on:** GT1, GT3
- **Goal:** Automatically create all five planning files (`requirements.md`, `decisions.md`, `roadmap.md`, `continuation.md`, `completion-log.md`) in `plan/` on `now` with the correct protocol headers and minimal starter content (per D27).
- **Acceptance:**
  - Init generates all five files in `plan/` on the `now` branch.
  - Each file carries the protocol header contract defined in §2.4 of `decisions.md`.
  - The initial `continuation.md` points at the first unfinished node rather than free text.

### GT6 — Bootstrap governed now-branch environment
- **Kind:** C
- **Depends on:** GT3
- **Goal:** Implement `bootstrap.sh` for the initialized repo.
- **Scope:**
  - set `core.hooksPath`
  - prepare derived cache directories
  - initialize only the required submodules non-recursively
  - verify the working tree is ready for governed operations
  - leave retryable state or explicit recovery instructions on failure
- **Acceptance:**
  - A fresh checkout of `now` becomes governed with one bootstrap step.
  - Bootstrap does not recurse through naive self-referential submodule workflows.
  - Failure messages tell the operator what is missing and whether rerun is safe.

### GT7 — Role parser and static config validation
- **Kind:** C
- **Depends on:** GT4, GT6
- **Goal:** Implement config parsing for `.gitmodules` custom keys and reject malformed role declarations.
- **Acceptance:**
  - Missing role keys, invalid roles, and future modules lacking ancestor declarations are detected.
  - Validation can run standalone against a fixture repo.

### GT8a — Constraint engine v1: past monotonicity
- **Kind:** C
- **Depends on:** GT7
- **Goal:** Implement and test monotonic advancement checks for past pins.
- **Acceptance:**
  - Fixture repos cover accepted and rejected past-pin transitions.
  - Violating past-pin changes are rejected before commit in normal operation.

### GT8b — Constraint engine v1: grounded futures
- **Kind:** C
- **Depends on:** GT7
- **Goal:** Implement and test future ancestry checks against named past lineage.
- **Acceptance:**
  - Fixture repos cover valid and invalid grounding.
  - Grounding checks are evaluated from the candidate resulting composition.

### GT8c — Constraint engine v1: atomic cross-check pass
- **Kind:** C
- **Depends on:** GT8a, GT8b
- **Goal:** Implement the all-or-nothing evaluator that checks the resulting configuration, including future retirement/removal semantics.
- **Acceptance:**
  - Cross-constraint invalidation is tested rather than assumed.
  - Removing a future from the resulting composition retires it cleanly from subsequent checks.

### GT9 — Immune-response design closure
- **Kind:** Q
- **Depends on:** GT8c
- **Goal:** Decide the post-detection response mechanism for bypassed violations.
- **Alternatives to test:**
  - auto-revert
  - tag-and-refuse-next
  - tag-and-degrade
- **Acceptance:**
  - One mechanism is chosen with recorded reasons.
  - Mechanical edge cases discovered during testing are captured in the design.
  - Rewrite-sensitive hook paths are explicitly covered.

### GT10 — Implement immune-response layer
- **Kind:** C
- **Depends on:** GT9
- **Goal:** Add the non-bypassable response path using `post-commit`, `post-merge`, `post-rewrite`, or the chosen equivalent.
- **Acceptance:**
  - A `--no-verify` violation produces at most one bad commit before the system responds.
  - The response is visible and leaves a durable trace.
  - The repo does not silently continue in a violated state.

### GT11 — Meta self-consistency mechanism
- **Kind:** C
- **Depends on:** GT8c
- **Goal:** Implement the first practical mechanism for detecting divergence between active enforcement machinery and declared meta state.
- **Acceptance:**
  - A controlled mismatch is detectable.
  - The mechanism is stable across normal line-ending/platform variation or else documents exact platform assumptions.

### GT12 — Worktree provisioning and operator ergonomics
- **Kind:** C
- **Depends on:** GT3
- **Goal:** Add optional commands for creating the standard worktree layout and making the temporal roles tangible in the filesystem.
- **Acceptance:**
  - Standard worktrees for `now`, one `past`, one `meta`, and at least one `future` can be created from the initialized repo.
  - The command is safe to skip; worktrees remain an ergonomic layer, not a hidden dependency.

### GT13 — End-to-end fixture repo and smoke scenarios
- **Kind:** H
- **Depends on:** GT10, GT11, GT12
- **Goal:** Build a reproducible fixture/demo repo and scripted smoke cases that exercise initialization, bootstrap, valid composition, invalid composition, and bypass response.
- **Acceptance:**
  - One command runs the smoke scenarios locally.
  - The scenarios produce outputs suitable for regression testing and future agent use.

### GT14 — GitHub template packaging
- **Kind:** H
- **Depends on:** GT2, GT13
- **Goal:** Package the scaffold repo so it works cleanly as a GitHub template.
- **Scope:**
  - repository settings/docs for “Use this template” flow
  - README for pre-init vs post-init state
  - optional GitHub CLI path
  - explicit warning that template generation alone does not produce the final governed topology until init runs
- **Acceptance:**
  - A new operator can generate a repo from the template and understand the next command without reading design internals.
  - Packaging docs only describe workflows that actually exist in the implemented spine.

### GT15 — Fresh-repo acceptance from GitHub template to governed membrane
- **Kind:** H
- **Depends on:** GT13, GT14
- **Goal:** Validate the whole path from template generation to governed operation in a brand-new repo.
- **Acceptance:**
  - Starting from a newly generated GitHub repo, the operator can reach a governed `now` branch with working constraints by following the documented steps.
  - The acceptance script records concrete checks instead of prose claims.

### GT16 — Hardening, split policy, and first-release cut
- **Kind:** H
- **Depends on:** GT15
- **Goal:** Convert the working prototype into a releasable template with explicit known limitations and a policy for future interstitial roadmap nodes.
- **Deliverables:**
  - release notes / known limitations
  - documented split policy for oversized future nodes
  - version tag criteria
- **Acceptance:**
  - The repo can be handed to another operator as a disciplined starter, not just a proof of concept.

## Suggested critical path

1. Record GT0 as closed, then stop spending design energy there.
2. Implement the topology initializer before spending effort on fine-grained enforcement.
3. Get the minimal constraint engine working before solving immune response and meta self-consistency.
4. Treat GitHub template packaging as a late packaging node, not the architectural core.

## Immediate next node

**GT2 — Initializer UX and idempotence contract**

GT1 is resolved: the canonical initialized layout, branch naming, planning-file placement, and provenance invariants are settled in `decisions.md` (D3-LAYOUT, D24–D27). The next live boundary is to specify the user-facing init entry point, its idempotence/recovery model, and failure semantics so GT3 can implement without hidden product decisions.
