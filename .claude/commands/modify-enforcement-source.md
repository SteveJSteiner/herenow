# `/modify-enforcement-source`

## When this command applies

Use this when changing enforcement source under `.now/hooks/*` or `.now/src/*`.

## Truth sources

- `.now/src/check-meta-consistency.sh`
- `.now/src/update-manifest.sh`
- `.now/src/check-composition.sh`
- `.now/hooks/pre-commit` and `.now/src/immune-response.sh`

## Preconditions

- On `now` in an initialized, bootstrapped repo.
- A `meta` gitlink is present in the index.
- Intended changes are enforcement-source changes (optionally with companion docs).

## Steps

1. Edit enforcement files (`.now/hooks/*`, `.now/src/*`).
2. Record exactly which enforcement files you changed:
   ```sh
   git status --short .now/hooks .now/src
   ```
3. Run meta consistency check before manifest update:
   ```sh
   sh .now/src/check-meta-consistency.sh .gitmodules
   ```
   Expected after enforcement edits: failure is normal and diagnostic. Why: the checker reads the **meta pin from index**, then compares its `enforcement-manifest` hashes to your current working-tree enforcement files.
   Confirm that the checker names exactly the file(s) you just edited. If it names an untouched file, stop: that is not expected drift from this edit, but a pre-existing inconsistency that must be resolved first.
4. Regenerate and stage manifest + pins atomically:
   ```sh
   sh .now/src/update-manifest.sh
   ```
   This updates `enforcement-manifest` on `meta`, stages the new `meta` gitlink on `now`, and stages the manifested enforcement files.
5. Verify meta consistency now passes:
   ```sh
   sh .now/src/check-meta-consistency.sh .gitmodules
   ```
6. Optionally run full composition check after manifest alignment:
   ```sh
   sh .now/src/check-composition.sh .gitmodules
   ```
7. Commit (or bottom out through `/now-commit` if following a shared flow):
   ```sh
   git commit -m "Update enforcement source"
   ```

## Verification

- Pre-update `check-meta-consistency.sh` failure was observed and explained.
- Pre-update mismatch list was confirmed to match only intentionally edited files.
- Post-update `check-meta-consistency.sh` passes.
- Commit accepted by pre-commit and not auto-reverted by post-hook.

## Failure protocol

- If pre-update check unexpectedly passes, first verify a `meta` gitlink is present in the index:
  ```sh
  git ls-files --stage -- meta
  ```
  If no staged gitlink is present, stop: governed state is incomplete or damaged and must be repaired before proceeding. If the gitlink is present, confirm you actually edited enforcement files.
- If pre-update check fails on untouched files, stop and diagnose baseline consistency before proceeding.
- If post-update check still fails, stop and inspect:
  - `git ls-files --stage meta`
  - `git diff --cached -- .now/hooks .now/src`
  - checker output details
- Do not bypass hooks to force a commit.

## Evidence to report

- Edited-file list from `git status --short .now/hooks .now/src`.
- Before/after `check-meta-consistency.sh` outputs.
- `update-manifest.sh` output including new `meta` commit SHA.
- Staged `meta` gitlink line and staged enforcement diff.
- Final commit SHA and short log showing no revert.
