# `/now-commit`

## When this command applies

Use this as the generic bottom-out commit flow for writes on `now`. Other write commands should end here unless they already perform the final commit.

## Truth sources

- `.now/hooks/pre-commit`
- `.now/hooks/post-commit`
- `.now/src/check-composition.sh`
- `.now/src/immune-response.sh`

## Preconditions

- On `now`.
- Bootstrap complete (`core.hooksPath=.now/hooks`, enforcement tree present).
- Staged diff reviewed and intentional.
- No bypass flags (`--no-verify`) are planned.

## Steps

1. Confirm branch + bootstrap:
   ```sh
   test "$(git symbolic-ref --short HEAD)" = "now"
   test "$(git config core.hooksPath)" = ".now/hooks"
   test -d .now/src && test -d .now/hooks
   ```
2. Review staged state:
   ```sh
   git status --short
   git diff --cached --stat
   ```
3. Preflight composition check when `.gitmodules` is present:
   ```sh
   test -f .gitmodules && sh .now/src/check-composition.sh .gitmodules
   ```
   Why here: this catches composition failures before the commit attempt, so you get diagnostics instead of a rejected commit or an avoidable auto-revert.
4. Commit without bypass:
   ```sh
   git commit -m "<message>"
   ```
5. Inspect recent history:
   ```sh
   git log --oneline -n 5
   ```
6. Re-run composition check post-commit when applicable:
   ```sh
   test -f .gitmodules && sh .now/src/check-composition.sh .gitmodules
   ```
   Why here: this confirms the committed state still passes and that immune response did not fire after the hook path ran.

## Verification

- Pre-commit accepted the commit.
- No post-commit immune-response auto-revert was triggered.
- Post-commit composition check still passes.

## Failure protocol

- If pre-commit blocks: stop, fix staged state based on checker output, retry.
- If auto-revert occurs: stop, inspect violating delta in log/diff, restage corrected change, recommit.
- If post-commit composition fails: treat as unresolved defect; do not proceed with additional writes.

## Evidence to report

- Staged diff summary before commit.
- Commit SHA + `git log --oneline -n 5` excerpt.
- Pre/post checker outputs.
