# `/create-future`

## When this command applies

Use this to declare and pin a new `future/<name>` branch grounded to an existing past submodule.

## Truth sources

- helper: `.now/src/create-future.sh`
- checker: `.now/src/validate-gitmodules.sh`
- checker: `.now/src/check-future-grounding.sh`
- checker: `.now/src/check-composition.sh`

## Preconditions

- On `now`.
- Target past submodule exists in `.gitmodules` with `role = past`.
- `ancestor-constraint` names the **past submodule** (for example `past/rca0`), not a SHA.
- `<name>` must not contain `/` or `.` (helper enforces this).

## Steps

1. Run helper script:
   ```sh
   sh .now/src/create-future.sh <name> <past-submodule> [<start-point>]
   ```
2. Review staged declaration/pin:
   ```sh
   git diff --cached -- .gitmodules
   git ls-files --stage -- "future/<name>"
   ```
3. Run checks:
   ```sh
   sh .now/src/validate-gitmodules.sh .gitmodules
   sh .now/src/check-future-grounding.sh .gitmodules
   sh .now/src/check-composition.sh .gitmodules
   ```
   Mechanically:
   - `validate-gitmodules.sh` proves role/url/path schema and ancestor-constraint semantics are valid.
   - `check-future-grounding.sh` proves the future pin and constrained past pin share non-trivial ancestry.
   - `check-composition.sh` proves the full composition still passes.
4. Commit via `/now-commit` or direct `git commit`.

## Verification

- `.gitmodules` includes `role = future` and `ancestor-constraint = <past-submodule>`.
- Grounding check confirms non-trivial shared ancestry with constrained past.
- Composition still passes.

## Failure protocol

- Stop if past submodule is missing or has wrong role.
- Stop if helper rejects `<name>` format.
- Stop if grounding fails; adjust branch lineage, do not invent new key names.
- Stop on any checker failure before commit.

## Evidence to report

- Helper output with future branch SHA.
- `.gitmodules` staged diff for future section.
- grounding/composition checker outputs.
- final commit SHA.
