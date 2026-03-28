# `/membrane-status`

## When this command applies

Use this for a read-only classification of repository state and current governance health.

## Truth sources

- `init.sh`
- seeded `bootstrap.sh`
- `.now/src/check-composition.sh`
- `.now/src/validate-gitmodules.sh`
- `.now/src/check-past-monotonicity.sh`
- `.now/src/check-future-grounding.sh`
- `.now/src/check-meta-consistency.sh`

## Preconditions

- Run from repository root.
- This command does not edit refs, index, or working tree.

## Steps

1. Detect branch and initialization state conditionally:
   ```sh
   git symbolic-ref --short HEAD 2>/dev/null || echo "detached"
   if git rev-parse --verify refs/membrane/root >/dev/null 2>&1; then
     echo "state: initialized"
   else
     echo "state: scaffold/uninitialized"
   fi
   ```
2. If uninitialized, report scaffold status and stop without checker noise:
   ```sh
   test -d .now/hooks && test -d .now/src && echo "scaffold enforcement files present"
   ```
3. If initialized, inspect whether bootstrap is active:
   ```sh
   git config core.hooksPath || true
   test -d .now/hooks && test -d .now/src && echo "enforcement tree present"
   test -d meta && test -n "$(ls -A meta 2>/dev/null)" && echo "meta initialized"
   ```
4. Classify state:
   - `scaffold / uninitialized`: no `refs/membrane/root`.
   - `initialized, not bootstrapped`: root exists but hooksPath/meta init not complete.
   - `bootstrapped governed`: root exists, on `now`, `core.hooksPath=.now/hooks`, enforcement tree present.
5. Run composition checks **only if** initialized + on `now` + enforcement files exist + `.gitmodules` exists:
   ```sh
   if git rev-parse --verify refs/membrane/root >/dev/null 2>&1 \
      && [ "$(git symbolic-ref --short HEAD 2>/dev/null || true)" = "now" ] \
      && [ -d .now/src ] && [ -f .now/src/check-composition.sh ] \
      && [ -f .gitmodules ]; then
     sh .now/src/check-composition.sh .gitmodules
   else
     echo "composition check skipped (state not eligible)"
   fi
   ```

## Verification

- State is clearly classified into one of the three states.
- In scaffold state, output is informative and quiet (no failing ref checks by default).
- In eligible governed state, composition checker output is reported.

## Failure protocol

- If initialized state is detected but `.now/src` is missing, stop and inspect initialization lineage.
- If bootstrapped expectations fail, direct operator to `/init-bootstrap-first-commit` bootstrap step.

## Evidence to report

- Branch name.
- State classification.
- `core.hooksPath` value (or unset).
- Whether `meta/` is initialized.
- Whether composition check ran or was skipped, and why.
