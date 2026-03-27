# `/init-bootstrap-first-commit`

## When this command applies

Use this when starting from scaffold state and entering governed operation for the first time.

## Truth sources

- `README.md` setup sections
- `init.sh`
- seeded `bootstrap.sh`
- `.claude/commands/modify-enforcement-source.md`
- `.claude/commands/now-commit.md`

## Preconditions

- Repo is scaffold/uninitialized.
- You can run shell scripts from repository root.

## Steps

1. Confirm scaffold pre-state:
   ```sh
   git status --short
   git rev-parse --verify refs/membrane/root >/dev/null 2>&1 || echo "uninitialized"
   ```
2. Initialize membrane topology:
   ```sh
   ./init.sh
   ```
3. Confirm initialization artifacts:
   ```sh
   git symbolic-ref --short HEAD
   git rev-parse --verify refs/membrane/root refs/heads/now refs/heads/meta refs/heads/provenance/scaffold
   ```
4. Bootstrap governance:
   ```sh
   ./bootstrap.sh
   ```
5. Confirm bootstrap completion:
   ```sh
   test "$(git config core.hooksPath)" = ".now/hooks"
   test -d meta && test -n "$(ls -A meta)"
   ```
6. Prepare an intentional **non-enforcement** change chosen by the operator and stage it.
   Reason: if this first governed change touches `.now/hooks/*` or `.now/src/*`, manifest alignment is required and you must switch to `/modify-enforcement-source` instead of using this simpler entry path.
   - Optional examples: add a short note file, adjust non-enforcement docs, or add a tiny fixture.
7. Bottom out into `/now-commit` to execute the governed commit sequence.

## Verification

- Initialization and bootstrap outputs confirm expected refs and hook activation.
- First governed commit is processed through `/now-commit` and accepted.

## Failure protocol

- If `init.sh` reports missing scaffold enforcement files, stop and verify branch/source tree.
- If `bootstrap.sh` fails submodule init, re-run from `now` after inspecting output.
- If staged first change touches enforcement files, stop and switch to `/modify-enforcement-source`.
- If first commit fails pre-commit checks, use checker output before retrying.

## Evidence to report

- `init.sh` output.
- `bootstrap.sh` output.
- ref SHAs for `refs/membrane/root`, `now`, `meta`.
- `/now-commit` evidence for the first governed commit.
