# `/create-past`

## When this command applies

Use this to declare and pin a new `past/<name>` branch in composition.

## Truth sources

- helper: `.now/src/create-past.sh`
- checker: `.now/src/validate-gitmodules.sh`
- checker: `.now/src/check-past-monotonicity.sh`
- checker: `.now/src/check-composition.sh`

## Preconditions

- On `now`.
- `.gitmodules` exists.
- Target name has no `/` and no `.` (helper enforces this).

## Steps

1. Run helper script:
   ```sh
   sh .now/src/create-past.sh <name> [<start-point>]
   ```
2. Review staged declaration/pin:
   ```sh
   git diff --cached -- .gitmodules
   git ls-files --stage -- "past/<name>"
   ```
3. Run relevant checks:
   ```sh
   sh .now/src/validate-gitmodules.sh .gitmodules
   sh .now/src/check-past-monotonicity.sh .gitmodules
   sh .now/src/check-composition.sh .gitmodules
   ```
   Mechanically:
   - `validate-gitmodules.sh` proves the new submodule declaration is schema-valid.
   - `check-past-monotonicity.sh` proves no past pin moved backward in ancestry.
   - `check-composition.sh` proves aggregate consistency across the full composition gate.
4. Commit via `/now-commit` or direct `git commit`.

## Verification

- Helper created or reused `past/<name>` and staged a gitlink.
- `.gitmodules` section has `role = past`, `url = ./`, `path = past/<name>`.
- Composition checks pass.

## Failure protocol

- Stop if helper reports existing declaration collision you did not intend.
- Stop if validation fails; fix declaration semantics rather than editing ad hoc.
- Stop if composition fails; inspect failing checker output before commit.

## Evidence to report

- Helper output (created/reused branch and SHA).
- `.gitmodules` staged diff.
- staged gitlink line.
- checker outputs and final commit SHA.
