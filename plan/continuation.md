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

- **Node ID:** GT4
- **Title:** Canonical `.gitmodules` schema and path policy
- **Status:** ACTIVE

## Why now

GT6 is complete — bootstrap works. GT7 (role parser and static config validation) depends on GT4 and GT6. GT6 is done; GT4 is the remaining blocker. GT4 settles the `.gitmodules` schema so the parser (GT7) can be implemented without guesswork.

## Dependencies

- `decisions.md` §3.2 (D5: role declaration via custom `.gitmodules` keys, D6-PATHS: OPEN — flat vs hierarchical)
- `decisions.md` §3.1 (D4: self-referencing submodules)
- `decisions.md` §4.2 (D9: futures descend from named past, `ancestor-constraint` key)
- `roadmap.md` (GT4 node definition and acceptance criteria)
- GT1 output: canonical skeleton and naming policy

## Output Files

- `decisions.md` (close D6-PATHS, define required keys per role, settle `.gitmodules` examples)
- `continuation.md` (refresh state while GT4 remains active)

## Local Context

- GT4 is a Q (design question) node. The deliverable is settled design, not code.
- D5 is closed: custom keys in `.gitmodules`, read via `git config --file .gitmodules --get submodule.<n>.role`.
- D6-PATHS is open: hierarchical (`past/rca0`, `future/sls`) vs flat (`rca0`, `sls`). Current leaning is flat.
- The `ancestor-constraint` key links futures to their named past lineage (D9).
- The `role` key is required for all submodules; valid values are `past`, `future`, `meta`.
- Meta submodule is already declared in init.sh with `role = meta`.

## Scope Boundary

In scope:
- close D6-PATHS (flat vs hierarchical submodule paths)
- define the complete set of required and optional `.gitmodules` keys per role
- provide concrete `.gitmodules` examples for each role (past, future, meta)
- ensure the schema is sufficient for GT7's parser/validator

Out of scope:
- implementing the parser/validator (GT7)
- adding actual past/future submodules (future roadmap nodes)
- resolving D7-PROVISIONING (submodule hook provisioning)

## Success Condition

- D6-PATHS is closed with a clear rationale.
- Required keys per role are enumerated (e.g., `role` always required, `ancestor-constraint` required for futures).
- `.gitmodules` examples cover past, future, and meta roles.
- The schema is concrete enough to implement a parser without ambiguity.

## Stress Test

- Can the examples be parsed by `git config --file .gitmodules`?
- Does the schema handle edge cases: multiple past branches, future with no ancestor-constraint (should be rejected), meta with ancestor-constraint (should be rejected or ignored)?
- Does the path policy accommodate renaming (future settling into past) without breaking submodule mechanics?

## Audit Target

- D6-PATHS is closed in `decisions.md`
- Required keys per role are documented
- Examples are parseable by git

## Verification

- `git config --file .gitmodules --get-regexp 'submodule\..*\.role'` returns valid role values for example entries
- The schema section in `decisions.md` is self-contained enough to implement GT7
