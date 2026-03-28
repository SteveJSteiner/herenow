---
description: "Install or restamp governed stance vocabulary and act-layer commands"
---

# `/install-stance`

## When this command applies

Use this after `./init.sh` + `./bootstrap.sh` when you need to install (or rerun) the governed stance layer from `meta/stance/*`.

## Truth sources

- `.now/src/install-stance.sh`
- `.now/src/commit-to-meta.sh`
- `meta/stance/vocabulary.toml`
- `meta/stance/STANCE.md.template`
- `meta/stance/commands/*.md.template`
- `CLAUDE.md`

## Preconditions

- You are on branch `now`.
- Bootstrap completed (`meta/` worktree is present).
- `meta/stance/vocabulary.toml` exists and is intentionally edited.

## Steps

1. Run installer:
   ```sh
   sh .now/src/install-stance.sh
   ```
2. If validation fails, edit `meta/stance/vocabulary.toml` and rerun.
3. If command-surface verification fails, remove/relocate unexpected markdown files in `.claude/commands/`, then rerun.

## Verification

- `STANCE.md` exists and matches current vocabulary/templates.
- `.claude/commands/.stance-generated` exists and lists six generated act commands.
- `CLAUDE.md` contains exactly one managed stance block.
- Slash-command surface is deliberate: `install-stance.md` + generated act commands only.

## Failure protocol

- If helper reports undeclared dirty meta paths, clean/isolate them and retry.
- If now-side commit fails or is auto-reverted after successful meta commit, follow the printed recovery instructions (resume from current point; do not rerun from scratch blindly).

## Evidence to report

- Meta SHA printed by installer.
- Now commit SHA (or no-op message on rerun).
- Final `.claude/commands/` file list.
- Any checker or immune-response output if recovery was required.
