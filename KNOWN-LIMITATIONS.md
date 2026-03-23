# Known Limitations

Current constraints and boundaries of the Temporal Membrane template. These are documented so that operators encounter them here, not by surprise during use.

## Platform requirements

- **POSIX shell.** All enforcement scripts, `init.sh`, and `bootstrap.sh` assume a POSIX-compatible shell (`/bin/sh`). They have not been tested on non-POSIX environments (e.g., Windows cmd, PowerShell without WSL).
- **Git 2.38+.** Bootstrap uses `protocol.file.allow=always` for the self-referencing meta submodule. Earlier git versions do not support this flag and will fail during `./bootstrap.sh`.

## Enforcement is local only

- Constraint checks run via git hooks (`core.hooksPath`). There is no CI/CD integration. Enforcement depends on the operator's local git configuration being intact.
- `core.hooksPath` can be overridden by the operator or by tooling. If it is changed, enforcement stops silently until the next meta self-consistency check detects the drift.
- Immune response (post-commit auto-revert, tag-and-refuse-next) is also hook-based. It cannot prevent a force-push of violated state to a remote.

## Enforcement installation is manual

- `init.sh` seeds the `now` branch with stub hooks and copies enforcement source from the scaffold. After initialization, the hooks on `now` are functional — but only after `bootstrap.sh` activates `core.hooksPath`.
- If enforcement source is updated on `provenance/scaffold` or `meta`, the operator must manually propagate changes to the active hooks on `now`. There is no automated sync mechanism.

## No past/future branch tooling

- The operator creates `past/*` and `future/*` branches manually. There is no command to add a past or future branch — the operator must create the branch, add the submodule entry to `.gitmodules` with the correct role and ancestor-constraint keys, and update the gitlink.
- Removing a future branch requires manually editing `.gitmodules` and removing the gitlink. The enforcement layer validates the resulting state but does not assist with the editing.

## No multi-remote or fork workflow

- The self-referencing submodule pattern (`url = ./`) assumes a single-remote, single-clone workflow. Forks, multiple remotes, or submodule URL rewriting have not been tested and may break submodule initialization.
- The initializer is local-only (D31). It does not configure remotes, push branches, or set up tracking.

## Now branch is a serialization point

- All composition changes go through `now`. Concurrent operators must coordinate on this branch. Git merge mechanics apply, but the constraint-checking hooks may reject merges that are individually valid but jointly inconsistent.

## Open design decisions

The following decisions were left intentionally open during the prototype phase. They do not block current operation but represent areas where the design may evolve:

| ID | Topic | Current state |
|----|-------|---------------|
| D7 | How now provisions submodule hooks | Not yet needed — enforcement runs from now's own hooks |
| D13 | Single vs. multiple past branches | Single past works; multiple past is untested |
| D18 | Enforcement source on now vs. in meta | Source lives on now; meta carries a manifest for consistency checks |
| D19 | Source language for enforcement logic | POSIX shell throughout; no migration threshold hit |
| D23 | Submodule initialization strategy | Bootstrap initializes meta only; other submodules are operator-managed |

## Scope of test coverage

- 162 assertions across 7 test suites (GT7, GT8a, GT8b, GT8c, GT12, GT13, GT15) plus dedicated immune-response and meta-consistency test harnesses.
- Tests exercise the init-to-governed path, constraint enforcement, immune response, worktree provisioning, and fresh-repo acceptance.
- Tests do not cover: multi-remote scenarios, non-POSIX platforms, git versions below 2.38, concurrent operator workflows, or large-scale submodule configurations.
