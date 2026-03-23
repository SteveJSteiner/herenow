# Temporal Membrane

A git-native repository discipline that enforces temporal structure — past, future, now, and meta — through git's own mechanisms. No external CI or platform policy required.

## Quick Start

### 1. Generate your repository

Use GitHub's **"Use this template"** button, or with the CLI:

```sh
gh repo create my-repo --template <this-template> --clone
cd my-repo
```

At this point you have the scaffold — a normal repository with `init.sh` and the enforcement source. The membrane topology does not exist yet.

### 2. Initialize the membrane

```sh
./init.sh
```

This creates the branch topology and checks out the `now` branch:

- `refs/membrane/root` — shared contentless origin
- `now` — the present composition surface (you land here)
- `meta` — operational self-governance
- `provenance/scaffold` — snapshot of the pre-init state

Re-running `./init.sh` is safe — it detects completed steps and skips them.

### 3. Bootstrap governance

```sh
./bootstrap.sh
```

This activates enforcement on the `now` branch:

- Sets `core.hooksPath` to `.now/hooks/`
- Initializes the `meta` submodule
- Verifies the governed state

After bootstrap, composition-changing commits on `now` are checked for past monotonicity, future grounding, and atomic consistency.

## What the branches mean

| Branch | Role | Contents |
|---|---|---|
| `now` | Present composition | Submodule pins, enforcement hooks, bootstrap, planning files |
| `meta` | Self-governance | Enforcement source carried as a submodule of `now` |
| `provenance/scaffold` | Provenance | Snapshot of the original scaffold state before init |
| *(past branches)* | Settled history | Created by the operator — monotonic, append-only |
| *(future branches)* | Grounded speculation | Created by the operator — must descend from a past branch |

## What gets enforced

On every commit to `now`, git hooks verify:

- **Past monotonicity** — past branch pins only move forward
- **Future grounding** — every future descends from its declared past
- **Composition consistency** — the full configuration is checked atomically
- **Meta self-consistency** — active hooks match the declared meta state
- **Bypass detection** — `--no-verify` commits are caught and blocked on the next governed operation

## Repository layout (pre-init)

```
init.sh          Initializer — run once to create the membrane topology
.now/
  hooks/         Git hooks (installed onto now branch by init)
  src/           Enforcement source (constraint checks, immune response)
  tests/         Tests for enforcement components
plan/            Scaffold planning documents (retained as provenance)
test/            Scaffold test suites
```

After initialization, the `now` branch carries its own layout with `bootstrap.sh`, `.gitmodules`, and `plan/` seeded fresh.

## Important

- **Template generation alone does not produce a governed repository.** You must run `./init.sh` followed by `./bootstrap.sh`.
- The initializer is purely additive — it never modifies or deletes existing refs.
- After initialization, the generated repository is sovereign. There is no implicit coupling back to the template.
