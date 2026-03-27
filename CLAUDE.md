# Claude Code Runtime Contract for `herenow`

Use this as the durable runtime layer for Claude Code in this repository.

## Truth precedence (highest first)

1. Runtime behavior in repository source (`.now/hooks/*`, `.now/src/*`, `init.sh`, seeded `bootstrap.sh`).
2. Executable checks/tests (`test/*`, `.now/tests/*`, smoke scripts).
3. Operator docs (`README.md`, `.claude/commands/*`).
4. Planning/rationale (`plan/*`) when not contradicted by source.
5. Agent prose and assumptions.

Repository source outranks agent prose. If prose conflicts with source, fix the prose.

## Operating rule

For any write operation, execute this sequence:

1. Read governing source.
2. Infer required state transition.
3. Act through helper scripts or explicit git commands.
4. Verify with the same checkers/hooks that will govern commit acceptance.
5. Report evidence (commands, outputs, SHAs, staged state).

## Grounded vocabulary

| Term | Mechanism in this repo |
| --- | --- |
| membrane | The governed branch/ref topology and hook/checker machinery created by `init.sh` and activated by `bootstrap.sh`. |
| meta | The `meta` branch/submodule that stores the `enforcement-manifest` commit history and is pinned on `now` via gitlink. |
| enforcement-manifest | File on `meta` listing blob hashes for enforcement files under `.now/hooks/*` and `.now/src/*`. |
| meta pin | The `meta` gitlink SHA read from the **index** (not from submodule working tree). |
| governed commit | Commit on `now` accepted by pre-hooks and not reverted by post-hook immune response. |
| immune response | Post-hook behavior in `.now/src/immune-response.sh` that auto-reverts violating commits. |
| constraint evaluator | `.now/src/check-composition.sh`, which orchestrates schema, past, future, and meta checks. |
| past monotonicity | `.now/src/check-past-monotonicity.sh`: new past pin must descend from prior HEAD pin. |
| future grounding | `.now/src/check-future-grounding.sh`: future pin must share non-trivial ancestry with its constrained past pin. |

## Command surface

Slash commands live in `.claude/commands/` and are command-oriented (not skill-triggered).
