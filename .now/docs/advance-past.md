# `/advance-past`

## When this command applies

Use this to move an existing past pin forward to a new commit.

## Truth sources

- helper: `.now/src/advance-past.sh`
- checker: `.now/src/check-past-monotonicity.sh`
- checker: `.now/src/check-composition.sh`

## Preconditions

- On `now`.
- Target submodule has `role = past`.
- New commit exists.

## Steps

1. Run helper script:
   ```sh
   sh .now/src/advance-past.sh <past-submodule> <new-commit>
   ```
2. Inspect staged old/new pin:
   ```sh
   git ls-files --stage -- <past-submodule>
   git diff --cached --submodule
   ```
3. Run checks:
   ```sh
   sh .now/src/check-past-monotonicity.sh .gitmodules
   sh .now/src/check-composition.sh .gitmodules
   ```
   Mechanically:
   - `check-past-monotonicity.sh` proves the new past pin descends from the old pin.
   - `check-composition.sh` proves this update remains valid in full composition context.
4. Commit via `/now-commit` or direct `git commit`.

## Verification

- New past pin is a descendant of prior pin.
- Composition passes after update.

## Failure protocol

- If monotonicity fails, **do not force** a non-descendant update. Stop and flag it.
- If helper reports missing index gitlink, stop and repair declaration/pin state first.
- Stop on any checker failure.

## Evidence to report

- old/new pin SHAs.
- monotonicity/composition outputs.
- final commit SHA.
