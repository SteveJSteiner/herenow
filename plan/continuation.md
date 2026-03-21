# Continuation — Single Current Task

## Protocol

- **Purpose:** the only active task for the current dispatch.
- **Authority:** current-task execution only.
- **Must contain:** one roadmap node ID, why now, dependencies, output files, local context, scope boundary, success condition, verification, stress test, audit target.
- **Must not contain:** multiple queued tasks, backlog items, roadmap-wide planning, long history.
- **Update rule:** after each commit, update this file to reflect the current active task state.
- **Update rule:** replace this file with the next single task only when the current task is completed or intentionally split.
- **Update rule:** if unfinished and still the same task, keep the same node ID and refresh only the local context/state as needed.

## Task Identity

- **Node ID:** GT1
- **Title:** Canonical skeleton and document contracts
- **Status:** ACTIVE

## Why now

GT0 is effectively closed: the GitHub-generated scaffold history is retained visibly as provenance, but it is out-of-band from the governed membrane lineage. The next blocked design boundary is to freeze the canonical initialized repository layout so GT2 (initializer UX), GT3 (topology creation), GT4 (schema/path policy), and GT5 (planning-file generation) all target one settled shape instead of improvising branch/file placement independently.

## Dependencies

- `requirements.md`
- `decisions.md`
- `roadmap.md` (GT1 node and GT0 resolved direction)
- current active design constraints to preserve:
  - `R1` / `D1`: common-root membrane lineage must remain intact
  - `R3` / `D18`: now branch may carry operational content, but the authoritative enforcement-source placement is still an open design choice
  - provenance stance from GT0: scaffold history remains visible but must not contaminate membrane ancestry checks
  - `D3-LAYOUT`: now-branch path/layout policy is still open
  - `D6-PATHS`: flat vs. hierarchical submodule paths remains open
  - `D7-PROVISIONING`: submodule hook provisioning model remains open

## Output Files

- `decisions.md` (canonical initialized layout, branch naming, file placement, and document-contract decisions)
- `requirements.md` (only if GT1 reveals a real requirements change rather than a design clarification)
- `roadmap.md` (only if GT1 changes downstream chunk boundaries or dependencies)
- `continuation.md` (refresh state while GT1 remains active)

## Local Context

- The generated GitHub template repository is only a scaffold. Initialization must create the actual governed membrane lineage with a fresh common root.
- The pre-init scaffold history is intentionally retained as visible provenance on an out-of-band branch.
- The roadmap already makes GT1 the next live node and expects it to settle:
  - canonical branch naming for now / past / future / meta / provenance
  - where `roadmap.md`, `continuation.md`, and `completion-log.md` live in the initialized repository
  - the canonical repository/path skeleton produced after initialization
- The current documents now have role-separated front matter, so GT1 should preserve those authority boundaries rather than collapsing requirements, design, and sequencing into one file.

## Scope Boundary

In scope:
- decide the canonical initialized branch set and naming policy
- decide where the planning files live after initialization
- decide the canonical top-level repository skeleton after initialization
- record any required invariants for provenance visibility without ancestry contamination
- update design/roadmap text so downstream implementation nodes target one settled structure

Out of scope:
- implementing the initializer command or bootstrap scripts
- resolving GT2 command UX / idempotence details beyond what GT1 must constrain
- implementing `.gitmodules` parsing or constraint hooks
- resolving D18 unless GT1 absolutely requires a minimal placement decision to avoid contradiction
- writing retrospective completion history beyond the minimal boundary update needed for planning files

## Success Condition

- a single canonical initialized layout exists and is recorded in `decisions.md`
- branch naming for now / past / future / meta / provenance is explicit rather than implied
- the intended location of `roadmap.md`, `continuation.md`, and `completion-log.md` is explicit
- downstream nodes GT2, GT3, GT4, and GT5 can proceed without making silent layout decisions

## Stress Test

- provenance separation case: the chosen layout keeps the visible scaffold/provenance branch inspectable without making it part of the membrane ancestry checked by enforcement
- D18 pressure case: the layout still works whether authoritative enforcement source ultimately lives on now or in meta
- path-policy pressure case: the skeleton does not preclude either flat or hierarchical submodule paths before GT4 closes that decision

## Audit Target

Audit these claims after GT1 lands:
- the canonical initialized layout is stated once in design authority rather than split ambiguously across requirements and roadmap prose
- planning-file placement is explicit enough for GT5 to generate files without guessing
- provenance is visible and named, but excluded from membrane-lineage reasoning
- no implementation order or task-execution instructions leaked into `decisions.md`

## Verification

- `rg -n "GT1|Canonical skeleton|document contracts|provenance|branch naming|completion-log|continuation|roadmap" roadmap.md decisions.md requirements.md`
- manual check that `decisions.md` contains the settled canonical initialized layout and planning-file placement
- manual check that any `requirements.md` edits are truly requirement-level and not design spillover
