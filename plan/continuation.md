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

- **Node ID:** GT7
- **Title:** Role parser and static config validation
- **Status:** READY

## Why now

GT4 is complete — the `.gitmodules` schema is settled (D6-PATHS closed: flat paths; required keys per role defined; validation rules specified). GT6 is complete — bootstrap works. GT7's two dependencies are satisfied. GT7 implements the parser/validator that all downstream constraint nodes (GT8a, GT8b, GT8c) depend on.

## Dependencies

- GT4 output: `.gitmodules` schema specification in `decisions.md` §3.2 (D5, D6-PATHS closed, validation rules 1–6)
- GT6 output: `bootstrap.sh` working, `.now/hooks/` structure, `core.hooksPath` set
- `decisions.md` §4.2 (D9: futures must descend from named past — informs what `ancestor-constraint` means)
- `roadmap.md` GT7 acceptance criteria

## Output Files

- Implementation of the parser/validator (location TBD — likely `.now/src/` or `.now/hooks/` depending on D18)
- Fixture `.gitmodules` files for testing (valid and invalid cases)
- `continuation.md` (refresh state while GT7 remains active)

## Local Context

- GT7 is a C (capability) node. The deliverable is working code, not design.
- The schema validation rules are in `decisions.md` §3.2: six static checks on `.gitmodules` content.
- Dynamic constraints (monotonic past, grounded futures) are out of scope — those are GT8a/GT8b.
- The parser reads `.gitmodules` via `git config --file .gitmodules --get-regexp`.
- The meta submodule is the only entry in `.gitmodules` at initialization. Past/future entries are added by operators later.
- D18 (enforcement source on now vs. in meta) and D19 (shell vs. compiled) are still open. The parser should start as shell to match D16/D22 (POSIX shell launchers, shell bootstrap).

## Scope Boundary

In scope:
- parse `.gitmodules` into structured role descriptors
- validate all six static schema rules from §3.2
- reject: missing role, invalid role value, future without ancestor-constraint, past/meta with ancestor-constraint, url != `./`, path != name
- produce clear error messages identifying which submodule and which rule failed
- run standalone against a fixture `.gitmodules` (per GT7 acceptance)

Out of scope:
- dynamic ancestry checks (GT8a, GT8b)
- hook integration (wiring into pre-commit — that comes when the constraint engine calls the parser)
- resolving D18 or D19

## Success Condition

- Missing role keys, invalid roles, and future modules lacking ancestor declarations are detected (GT7 acceptance).
- Validation can run standalone against a fixture repo (GT7 acceptance).
- All six schema rules produce correct accept/reject on fixture inputs.

## Stress Test

- Does the parser handle an empty `.gitmodules` (no submodules)?
- Does it handle a single meta entry (the init-time state)?
- Does it handle multiple pasts with multiple futures referencing different pasts?
- Does it correctly reject a future whose `ancestor-constraint` names a nonexistent submodule?
- Does it correctly reject a future whose `ancestor-constraint` names a `future` or `meta` submodule instead of a `past`?

## Audit Target

- Parser produces structured output from `.gitmodules`
- All six validation rules have fixture test cases (accept and reject)
- Error messages identify the failing submodule and rule

## Verification

- Run validator against valid fixture → exit 0, no errors
- Run validator against each invalid fixture → exit non-zero, error message names the violation
- `git config --file .gitmodules --get-regexp` underlies the parsing (no custom INI parser)
