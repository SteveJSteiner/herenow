# Completion Log

## Protocol Header
- **Purpose:** compact continuity ledger of material continuation transitions and handoff checkpoints.
- **Authority:** append-only continuation-transition log.
- **Must contain:** one line per material continuation transition or handoff checkpoint with date, node/slice ID, event, optional ref, brief accomplishment.
- **Must not contain:** long prose, design rationale, future planning, tiny intra-continuation fixes, pass-only notes.
- **Update rule:** append exactly one line when the active continuation materially changes or a real handoff checkpoint is created; never mutate prior lines.

## Logging Rules
- Continuation-transition cadence only.
- Human turns and small internal commits do not create lines by themselves.
- Append a line only when:
  - the current task is completed and continuation advances
  - the current task is split and continuation is replaced with a slice
  - the current task is replaced for repair/recovery/reprioritization
  - a meaningful WIP handoff checkpoint is created
- Do not append a line for:
  - tiny wording fixes
  - local cleanup commits
  - intermediate commits that do not change the active continuation state
- `<node-or-slice-id>` must be a real roadmap node/slice ID.
- No synthetic refs and no meaning encoded in node IDs.
- Event vocabulary: `done`, `split`, `replace`, `handoff`.

Format:
`YYYY-MM-DD | <node-or-slice-id> | <event> | <optional-short-hash> | <brief accomplishment>`

## Phase: GitHub Template Temporal Membrane (GT0–)

2026-03-21 | GT0 | done | - | Delivery mechanism closed: GitHub template scaffold retained visibly as provenance, while membrane branches are created post-init as a separate common-root governed lineage.
2026-03-21 | GT1 | handoff | - | Active continuation set to canonical skeleton and document contracts: freeze initialized branch/layout naming, planning-file placement, and provenance representation before implementation work begins.
