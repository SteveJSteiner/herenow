# Install Stance

The stance layer is installed post-init from governed source on `meta`.

## Flow

1. Initialize and bootstrap the repo (`./init.sh` then `./bootstrap.sh`).
2. Edit `meta/stance/vocabulary.toml`.
3. Run:
   ```sh
   sh .now/src/install-stance.sh
   ```

The installer commits vocabulary on `meta`, stamps `STANCE.md`, stamps six act-layer command docs in `.claude/commands/`, updates the managed `@STANCE.md` import block in `CLAUDE.md`, verifies command-surface minimality, and commits now-side artifacts.

If install fails after the meta commit succeeds, resume from the printed recovery point instead of rerunning from scratch.
