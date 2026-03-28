# `/graduate-future`

## When this command applies

Use this to settle a future branch into its constrained past lineage.

## Truth sources

- helper: `.now/src/graduate-future.sh`
- checker: `.now/src/validate-gitmodules.sh`
- checker: `.now/src/check-past-monotonicity.sh`
- checker: `.now/src/check-composition.sh`

## Preconditions

- On `now`.
- Future submodule exists with `role = future` and `ancestor-constraint`.
- Replacement past commit is chosen.

## Steps

1. Run helper script:
   ```sh
   sh .now/src/graduate-future.sh <future-submodule> <new-past-commit>
   ```
2. Inspect staged effects:
   ```sh
   git diff --cached -- .gitmodules
   git ls-files --stage -- <future-submodule>
   ```
   Use helper output or `.gitmodules` to identify the constrained past target; do not introduce a new operator input for it.
   ```sh
   # after resolving the constrained past submodule name from helper output or .gitmodules
   git ls-files --stage -- "<resolved-past-submodule>"
   ```
   Expectation: the future gitlink lookup returns no staged entry, while the constrained past gitlink shows the new requested SHA.
3. Run checks:
   ```sh
   sh .now/src/validate-gitmodules.sh .gitmodules
   sh .now/src/check-past-monotonicity.sh .gitmodules
   sh .now/src/check-composition.sh .gitmodules
   ```
   Mechanically:
   - `validate-gitmodules.sh` proves `.gitmodules` remains schema-valid after future removal.
   - `check-past-monotonicity.sh` proves the constrained past pin did not move backward.
   - `check-composition.sh` proves full composition remains valid after graduation.
4. Commit via `/now-commit` or direct `git commit`.

## Verification

- Future entry is removed from `.gitmodules`.
- Future gitlink is removed from index.
- Constrained past gitlink, resolved from `ancestor-constraint`, points at the requested new SHA.
- Composition still passes.

## Failure protocol

- Stop if future declaration is malformed (missing `ancestor-constraint`).
- Stop if staged future gitlink still exists.
- Stop if staged resolved past gitlink does not point to intended advanced SHA.
- Stop if past monotonicity or full composition fails.

## Evidence to report

- Helper output including resolved constrained past and target SHA.
- `.gitmodules` staged diff showing future removal.
- staged gitlink evidence (future removed, resolved past advanced).
- checker outputs and final commit SHA.
