#!/bin/sh
# init.sh — Initialize the temporal membrane branch topology.
#
# Transforms a repository generated from the GitHub template into the
# canonical membrane branch topology. One-time, non-interactive, idempotent.
#
# Exit codes:
#   0 — success or already initialized
#   1 — failure
#
# See decisions.md §7 (D28–D31) for the design contract.

set -eu

# --- Preamble ---

GIT_DIR="$(git rev-parse --git-dir)"
TEMP_INDEX="$GIT_DIR/index.init.tmp"
TEMP_ENTRIES="$GIT_DIR/entries.init.tmp"

trap 'rm -f "$TEMP_INDEX" "$TEMP_ENTRIES"' EXIT

# --- Helpers ---

blob() { git hash-object -w --stdin; }

add_entry() {
    GIT_INDEX_FILE="$TEMP_INDEX" git update-index --add --cacheinfo "$1" "$2" "$3"
}

write_temp_tree() {
    GIT_INDEX_FILE="$TEMP_INDEX" git write-tree
}

read_into_temp() {
    rm -f "$TEMP_INDEX"
    GIT_INDEX_FILE="$TEMP_INDEX" git read-tree "$1"
}

# --- Step guards ---

step1_done() {
    git rev-parse --verify refs/membrane/root >/dev/null 2>&1
}

step2_done() {
    git rev-parse --verify refs/heads/provenance/scaffold >/dev/null 2>&1
}

# Check if a membrane branch exists and descends from the root.
# Returns 0 if done, 1 if not done, exits if conflicting branch exists.
check_membrane_branch() {
    _branch="$1"
    if git rev-parse --verify "refs/heads/$_branch" >/dev/null 2>&1; then
        if step1_done; then
            _root=$(git rev-parse refs/membrane/root)
            _tip=$(git rev-parse "refs/heads/$_branch")
            if [ "$_tip" = "$_root" ] || \
               git merge-base --is-ancestor "$_root" "$_tip" 2>/dev/null; then
                return 0
            fi
        fi
        echo "Error: Branch '$_branch' exists but is not part of the membrane topology." >&2
        echo "init.sh is purely additive and will not modify existing refs (D29)." >&2
        exit 1
    fi
    return 1
}

step3_done() { check_membrane_branch now; }
step4_done() { check_membrane_branch meta; }

step5_done() {
    _hooks=$(git ls-tree "refs/heads/now" -- .now/hooks/ 2>/dev/null) || return 1
    _src=$(git ls-tree "refs/heads/now" -- .now/src/ 2>/dev/null) || return 1
    _docs=$(git ls-tree "refs/heads/now" -- .now/docs/ 2>/dev/null) || return 1
    _install=$(git ls-tree "refs/heads/now" -- .claude/commands/install-stance.md 2>/dev/null) || return 1
    _claude=$(git ls-tree "refs/heads/now" -- CLAUDE.md 2>/dev/null) || return 1
    [ -n "$_hooks" ] && [ -n "$_src" ] && [ -n "$_docs" ] && [ -n "$_install" ] && [ -n "$_claude" ]
}

step6_done() {
    git rev-parse --verify "refs/heads/meta:enforcement-manifest" >/dev/null 2>&1 || return 1
    git rev-parse --verify "refs/heads/meta:stance/vocabulary.toml" >/dev/null 2>&1 || return 1
    git rev-parse --verify "refs/heads/meta:stance/STANCE.md.template" >/dev/null 2>&1 || return 1
    git rev-parse --verify "refs/heads/meta:stance/commands/show.md.template" >/dev/null 2>&1 || return 1
    git rev-parse --verify "refs/heads/meta:stance/commands/explore.md.template" >/dev/null 2>&1 || return 1
    git rev-parse --verify "refs/heads/meta:stance/commands/integrate.md.template" >/dev/null 2>&1 || return 1
    git rev-parse --verify "refs/heads/meta:stance/commands/finish.md.template" >/dev/null 2>&1 || return 1
    git rev-parse --verify "refs/heads/meta:stance/commands/change-rules.md.template" >/dev/null 2>&1 || return 1
    git rev-parse --verify "refs/heads/meta:stance/commands/save.md.template" >/dev/null 2>&1 || return 1
    return 0
}

step7_done() {
    _output=$(git ls-tree "refs/heads/now" -- plan/ 2>/dev/null) || return 1
    [ -n "$_output" ]
}

# --- Full re-run detection ---

if step1_done && step2_done && step3_done && step4_done \
   && step5_done && step6_done && step7_done; then
    echo "Already initialized. Nothing to do."
    if [ "$(git symbolic-ref --short HEAD 2>/dev/null || true)" != "now" ]; then
        git checkout now
    fi
    exit 0
fi

# ===================================================================
# Step 1/8: Create root ref
# ===================================================================

if ! step1_done; then
    echo "Step 1/8: Creating membrane root..."
    _empty_tree=$(git mktree </dev/null)
    _root=$(git commit-tree "$_empty_tree" -m "membrane root")
    git update-ref refs/membrane/root "$_root"
    echo "  refs/membrane/root -> $_root"
fi

# ===================================================================
# Step 2/8: Record provenance
# ===================================================================

if ! step2_done; then
    echo "Step 2/8: Recording provenance..."
    _scaffold_tip=$(git rev-parse HEAD)
    git branch provenance/scaffold "$_scaffold_tip"
    echo "  provenance/scaffold -> $_scaffold_tip"
fi

# ===================================================================
# Step 3/8: Create now branch
# ===================================================================

if ! step3_done; then
    echo "Step 3/8: Creating now branch..."
    _root=$(git rev-parse refs/membrane/root)
    git branch now "$_root"
    echo "  now -> $_root"
fi

# ===================================================================
# Step 4/8: Create meta branch
# ===================================================================

if ! step4_done; then
    echo "Step 4/8: Creating meta branch..."
    _root=$(git rev-parse refs/membrane/root)
    git branch meta "$_root"
    echo "  meta -> $_root"
fi

# ===================================================================
# Step 5/8: Seed now-branch skeleton
# ===================================================================

if ! step5_done; then
    echo "Step 5/8: Seeding now-branch skeleton..."

    read_into_temp "refs/heads/now^{tree}"

    # Hooks and enforcement source from scaffold (HEAD tree).
    # The blobs are already in the object store — just reference them.
    git ls-tree -r HEAD -- .now/hooks/ .now/src/ > "$TEMP_ENTRIES" 2>/dev/null || true
    if ! grep -q '\.now/hooks/' "$TEMP_ENTRIES" 2>/dev/null || \
       ! grep -q '\.now/src/'   "$TEMP_ENTRIES" 2>/dev/null; then
        echo "Error: required seed paths (.now/hooks and .now/src) not found in HEAD." >&2
        echo "  Run init.sh from the scaffold branch (main), not from now." >&2
        exit 1
    fi
    while IFS= read -r _line; do
        [ -z "$_line" ] && continue
        _mode=$(printf '%s' "$_line" | awk '{print $1}')
        _sha=$(printf '%s'  "$_line" | awk '{print $3}')
        _path=$(printf '%s' "$_line" | awk -F'\t' '{print $2}')
        add_entry "$_mode" "$_sha" "$_path"
    done < "$TEMP_ENTRIES"
    rm -f "$TEMP_ENTRIES"

    # Fixed /install-stance command doc (seeded from scaffold HEAD; single source of truth).
    if git cat-file -e "HEAD:.claude/commands/install-stance.md" 2>/dev/null; then
        _blob=$(git show HEAD:.claude/commands/install-stance.md | blob)
    else
        _blob=$(blob <<'INSTALL_STANCE_CMD_FALLBACK'
---
description: "Install or restamp governed stance vocabulary and act-layer commands"
---

Run:

```sh
sh .now/src/install-stance.sh
```
INSTALL_STANCE_CMD_FALLBACK
)
    fi
    add_entry 100644 "$_blob" ".claude/commands/install-stance.md"

    # Root memory/runtime docs used by stance install.
    if git cat-file -e "HEAD:CLAUDE.md" 2>/dev/null; then
        _blob=$(git show HEAD:CLAUDE.md | blob)
    else
        _blob=$(blob '# Claude runtime contract.')
    fi
    add_entry 100644 "$_blob" "CLAUDE.md"

    if git cat-file -e "HEAD:INSTALL-STANCE.md" 2>/dev/null; then
        _blob=$(git show HEAD:INSTALL-STANCE.md | blob)
    else
        _blob=$(blob '# Install stance with `sh .now/src/install-stance.sh`.')
    fi
    add_entry 100644 "$_blob" "INSTALL-STANCE.md"

    # Non-command substrate/operator reference docs.
    if git cat-file -e "HEAD:.now/docs/membrane-status.md" 2>/dev/null; then
        _blob=$(git show HEAD:.now/docs/membrane-status.md | blob)
    else
        _blob=$(blob '# membrane-status reference')
    fi
    add_entry 100644 "$_blob" ".now/docs/membrane-status.md"
    if git cat-file -e "HEAD:.now/docs/init-bootstrap-first-commit.md" 2>/dev/null; then
        _blob=$(git show HEAD:.now/docs/init-bootstrap-first-commit.md | blob)
    else
        _blob=$(blob '# init-bootstrap-first-commit reference')
    fi
    add_entry 100644 "$_blob" ".now/docs/init-bootstrap-first-commit.md"
    if git cat-file -e "HEAD:.now/docs/now-commit.md" 2>/dev/null; then
        _blob=$(git show HEAD:.now/docs/now-commit.md | blob)
    else
        _blob=$(blob '# now-commit reference')
    fi
    add_entry 100644 "$_blob" ".now/docs/now-commit.md"
    if git cat-file -e "HEAD:.now/docs/modify-enforcement-source.md" 2>/dev/null; then
        _blob=$(git show HEAD:.now/docs/modify-enforcement-source.md | blob)
    else
        _blob=$(blob '# modify-enforcement-source reference')
    fi
    add_entry 100644 "$_blob" ".now/docs/modify-enforcement-source.md"
    if git cat-file -e "HEAD:.now/docs/create-past.md" 2>/dev/null; then
        _blob=$(git show HEAD:.now/docs/create-past.md | blob)
    else
        _blob=$(blob '# create-past reference')
    fi
    add_entry 100644 "$_blob" ".now/docs/create-past.md"
    if git cat-file -e "HEAD:.now/docs/create-future.md" 2>/dev/null; then
        _blob=$(git show HEAD:.now/docs/create-future.md | blob)
    else
        _blob=$(blob '# create-future reference')
    fi
    add_entry 100644 "$_blob" ".now/docs/create-future.md"
    if git cat-file -e "HEAD:.now/docs/advance-past.md" 2>/dev/null; then
        _blob=$(git show HEAD:.now/docs/advance-past.md | blob)
    else
        _blob=$(blob '# advance-past reference')
    fi
    add_entry 100644 "$_blob" ".now/docs/advance-past.md"
    if git cat-file -e "HEAD:.now/docs/graduate-future.md" 2>/dev/null; then
        _blob=$(git show HEAD:.now/docs/graduate-future.md | blob)
    else
        _blob=$(blob '# graduate-future reference')
    fi
    add_entry 100644 "$_blob" ".now/docs/graduate-future.md"
    if git cat-file -e "HEAD:.now/docs/commands-register.md" 2>/dev/null; then
        _blob=$(git show HEAD:.now/docs/commands-register.md | blob)
    else
        _blob=$(blob '# commands register guidance')
    fi
    add_entry 100644 "$_blob" ".now/docs/commands-register.md"

    # bootstrap.sh
    _bootstrap_blob=$(blob <<'BOOTSTRAP'
#!/bin/sh
# bootstrap.sh — activate the governed environment on the now branch.
# Idempotent — safe to re-run. See decisions.md §8 (D22, D23).
set -eu

# --- Preconditions ---

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not inside a git repository." >&2
    echo "Recovery: cd into the repo and re-run ./bootstrap.sh" >&2
    exit 1
fi

if ! git rev-parse --verify refs/membrane/root >/dev/null 2>&1; then
    echo "Error: repository not initialized (refs/membrane/root missing)." >&2
    echo "Recovery: run ./init.sh first, then ./bootstrap.sh" >&2
    exit 1
fi

_branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
if [ "$_branch" != "now" ]; then
    echo "Error: not on the now branch (current: ${_branch:-detached HEAD})." >&2
    echo "Recovery: git checkout now && ./bootstrap.sh" >&2
    exit 1
fi

# --- Step 1: Activate hooks ---

_hooks_dir=".now/hooks"

if [ ! -d "$_hooks_dir" ]; then
    echo "Error: $_hooks_dir not found." >&2
    echo "Recovery: verify the now branch skeleton is intact, then re-run." >&2
    exit 1
fi

git config core.hooksPath "$_hooks_dir"

for _hook in "$_hooks_dir"/*; do
    [ -f "$_hook" ] && chmod +x "$_hook"
done

echo "  hooks -> $_hooks_dir"

# --- Step 2: Verify enforcement source ---

if [ ! -d ".now/src" ]; then
    echo "Error: .now/src/ not found." >&2
    echo "Recovery: verify init.sh completed successfully, then re-run bootstrap.sh." >&2
    exit 1
fi

echo "  enforcement source ready"

# --- Step 3: Initialize meta submodule (selective, non-recursive) ---
# URL override: .gitmodules declares url=./ which resolves to the remote,
# but the meta branch may only exist locally. Point to the local repo.

if [ -f ".gitmodules" ]; then
    _repo=$(git rev-parse --show-toplevel)
    git submodule init meta >/dev/null 2>&1 || true
    git config submodule.meta.url "$_repo"
    git -c protocol.file.allow=always submodule update meta || {
        echo "Error: failed to initialize meta submodule." >&2
        echo "Recovery: re-run ./bootstrap.sh (safe to retry)." >&2
        exit 1
    }
    echo "  meta submodule ready"
else
    echo "Warning: .gitmodules not found — skipping submodule init." >&2
fi

# --- Verify ---

_ok=true

_hp=$(git config core.hooksPath || true)
if [ "$_hp" != "$_hooks_dir" ]; then
    echo "FAIL: core.hooksPath = '${_hp:-unset}' (expected '$_hooks_dir')" >&2
    _ok=false
fi

if [ ! -d "meta" ] || [ -z "$(ls -A meta 2>/dev/null)" ]; then
    echo "FAIL: meta/ is missing or empty." >&2
    _ok=false
fi

if [ "$_ok" != true ]; then
    echo "Bootstrap incomplete. Re-run ./bootstrap.sh to retry." >&2
    exit 1
fi

echo "Bootstrap complete."
BOOTSTRAP
)
    add_entry 100755 "$_bootstrap_blob" "bootstrap.sh"

    # .gitmodules
    _gitmodules_blob=$(blob <<'GITMODULES'
[submodule "meta"]
	path = meta
	url = ./
	role = meta
GITMODULES
)
    add_entry 100644 "$_gitmodules_blob" ".gitmodules"

    # .gitignore
    _gitignore_blob=$(blob <<'GITIGNORE'
.now/bin/
GITIGNORE
)
    add_entry 100644 "$_gitignore_blob" ".gitignore"

    _tree=$(write_temp_tree)
    _parent=$(git rev-parse refs/heads/now)
    _commit=$(git commit-tree "$_tree" -p "$_parent" -m "Initialize now-branch skeleton")
    git update-ref refs/heads/now "$_commit"
    echo "  now skeleton -> $_commit"
fi

# ===================================================================
# Step 6/8: Seed meta branch
# ===================================================================

if ! step6_done; then
    echo "Step 6/8: Seeding meta branch..."

    read_into_temp "refs/heads/meta^{tree}"

    _readme_blob=$(blob <<'README'
# Meta

Operational self-governance artifacts for the temporal membrane.

This branch carries enforcement tooling, provisioning scripts, and
operational machinery. It is pinned from the `now` branch as a submodule.

The meta branch is about how the present governs itself — distinct from
what the present is doing (which lives on `now` in `plan/`).
README
)
    add_entry 100644 "$_readme_blob" "README.md"

    # Generate enforcement manifest from the files seeded onto now in step 5.
    # Format: <blob-hash> <file-path> — one line per file in .now/hooks/ and .now/src/.
    # check-meta-consistency.sh reads this manifest from the meta pin and compares
    # each listed file against the working tree on every governed commit.
    _manifest_blob=$(
        { printf '# Enforcement manifest — auto-generated by init.sh\n'
          git ls-tree -r "refs/heads/now" -- .now/hooks/ .now/src/ 2>/dev/null \
              | awk -F'\t' '{split($1,a," "); printf "%s %s\n", a[3], $2}'
        } | blob
    )
    add_entry 100644 "$_manifest_blob" "enforcement-manifest"

    # Governed stance install source (post-init install layer).
    _blob=$(blob <<'VOCAB'
# Fill this manifest, then run /install-stance.
# Quoted values only in this first implementation.

[stance]
title = ""
description = ""
floor = ""
claim = ""
experiment = ""
blocked = ""

[commands]
show = ""
explore = ""
integrate = ""
finish = ""
change_rules = ""
save = ""
VOCAB
)
    add_entry 100644 "$_blob" "stance/vocabulary.toml"

    _blob=$(blob <<'STANCE_TEMPLATE'
# {{stance.title}}

{{stance.description}}

## Working language

This overlay defines the operative language used by the act-layer commands installed in `.claude/commands/`.
`CLAUDE.md` remains the root memory authority for enforcement substrate and truth precedence.

## Noun semantics

- **{{stance.floor}}** — the current grounded state (facts, constraints, pins, checker outcomes).
- **{{stance.claim}}** — the current assertion about what should be done or is true.
- **{{stance.experiment}}** — the next concrete trial intended to raise confidence or expose failure.
- **{{stance.blocked}}** — explicit block conditions that prevent safe forward motion.

Treat these four nouns as mutually distinct categories. If a case does not fit cleanly, classify it as `{{stance.blocked}}` until clarified.

## Act mapping

- `/{{commands.show}}` — classify current state into `{{stance.floor}}` / `{{stance.claim}}` / `{{stance.experiment}}` / `{{stance.blocked}}`.
- `/{{commands.explore}}` — generate and compare candidate `{{stance.experiment}}` moves from the current `{{stance.floor}}`.
- `/{{commands.integrate}}` — integrate validated content through normal git operations and governed commit on `now`.
- `/{{commands.finish}}` — close a cycle with evidence and clear classification updates.
- `/{{commands.change_rules}}` — modify governed artifacts on `meta`, then commit through the governed path.
- `/{{commands.save}}` — persist concise continuation state in this vocabulary.

## Blocking and enforcement surface

When progress is blocked by governance or enforcement:

1. classify as `{{stance.blocked}}`,
2. identify the enforcing source (`.now/hooks/*`, `.now/src/*`, or checker output),
3. route to either ordinary content repair (`now`) or governed rule change (`meta`).

## Substrate mapping appendix

- Constraint evaluator: `.now/src/check-composition.sh`
- Meta consistency: `.now/src/check-meta-consistency.sh`
- Governed helper for meta commits: `.now/src/commit-to-meta.sh`
- Install machinery: `.now/src/install-stance.sh`
STANCE_TEMPLATE
)
    add_entry 100644 "$_blob" "stance/STANCE.md.template"

    _blob=$(blob <<'SHOW_TEMPLATE'
---
description: "Inspect where things stand — classify floor, claim, experiment, blocked"
---
<!-- generated-by: install-stance -->

# `/{{commands.show}}`

## When this command applies

Use this to produce a grounded status classification before planning or committing work.

## Truth sources

- `STANCE.md`
- `CLAUDE.md`
- checker outputs under `.now/src/`

## Preconditions

- Run from repository root.
- Prefer fresh checker output when state may have changed.

## Steps

1. Identify current `{{stance.floor}}` (facts and constraints).
2. State current `{{stance.claim}}`.
3. Propose current/next `{{stance.experiment}}`.
4. Record `{{stance.blocked}}` if any blocking condition exists.

## Verification

- Every claim is tied to source, checker output, or a command result.
- Any unresolved uncertainty is labeled `{{stance.blocked}}`.

## Failure protocol

- If classification is ambiguous, stop and gather evidence before proceeding.

## Evidence to report

- One concise four-part classification: floor / claim / experiment / blocked.
SHOW_TEMPLATE
)
    add_entry 100644 "$_blob" "stance/commands/show.md.template"

    _blob=$(blob <<'EXPLORE_TEMPLATE'
---
description: "Explore candidate moves and shape an experiment from current floor"
---
<!-- generated-by: install-stance -->

# `/{{commands.explore}}`

## When this command applies

Use this when `{{stance.floor}}` is known and you need to choose the next `{{stance.experiment}}`.

## Truth sources

- `STANCE.md`
- relevant checkers in `.now/src/`
- current git state (`git status`, staged diff, refs)

## Preconditions

- Current `{{stance.floor}}` and `{{stance.claim}}` are explicit.

## Steps

1. Enumerate candidate experiments grounded in current constraints.
2. For each candidate, describe mechanism-level execution.
3. Choose one experiment and define success/failure signals.

## Verification

- Proposed experiment can be executed via explicit git operations or repository scripts.
- Success/failure conditions are observable.

## Failure protocol

- If no safe experiment exists, classify as `{{stance.blocked}}` and route to `/{{commands.change_rules}}` or content repair.

## Evidence to report

- Chosen experiment, alternatives rejected, and reasons.
EXPLORE_TEMPLATE
)
    add_entry 100644 "$_blob" "stance/commands/explore.md.template"

    _blob=$(blob <<'INTEGRATE_TEMPLATE'
---
description: "Integrate validated work into now through governed commit flow"
---
<!-- generated-by: install-stance -->

# `/{{commands.integrate}}`

## When this command applies

Use this after an experiment is accepted and ready to land on `now`.

## Truth sources

- `STANCE.md`
- `.now/hooks/*`
- `.now/src/check-composition.sh`

## Preconditions

- Changes are reviewed and staged intentionally.
- Governance hooks are active (`core.hooksPath=.now/hooks`).

## Steps

1. Apply ordinary git content operations (edit/add/remove/stage).
2. Run relevant checkers before commit.
3. Commit on `now` through normal governed flow.

`/{{commands.integrate}}` is advisory only; it does not call a dedicated integrate helper.

## Verification

- Commit is accepted by governance and not auto-reverted.

## Failure protocol

- If pre-commit checks fail or immune response reverts, classify as `{{stance.blocked}}` and report enforcing mechanism.

## Evidence to report

- Commit SHA, checker outputs, and any governance diagnostics.
INTEGRATE_TEMPLATE
)
    add_entry 100644 "$_blob" "stance/commands/integrate.md.template"

    _blob=$(blob <<'FINISH_TEMPLATE'
---
description: "Finish a cycle by recording evidence, verification, and state transition"
---
<!-- generated-by: install-stance -->

# `/{{commands.finish}}`

## When this command applies

Use this to close the current cycle and hand off clearly.

## Truth sources

- current working tree/index/HEAD state
- checker outputs
- commit history from this cycle

## Preconditions

- The active experiment has reached a terminal state (accepted, rejected, or blocked).

## Steps

1. Summarize outcome against the initial `{{stance.claim}}`.
2. Report resulting `{{stance.floor}}`.
3. Record next `{{stance.experiment}}` or `{{stance.blocked}}`.

## Verification

- Outcome is traceable to concrete evidence.

## Failure protocol

- If evidence is incomplete, classify as `{{stance.blocked}}` and reopen exploration.

## Evidence to report

- Outcome summary, references to SHAs/checkers, and next-step classification.
FINISH_TEMPLATE
)
    add_entry 100644 "$_blob" "stance/commands/finish.md.template"

    _blob=$(blob <<'CHANGE_RULES_TEMPLATE'
---
description: "Change governed rules by editing meta artifacts and committing through meta"
---
<!-- generated-by: install-stance -->

# `/{{commands.change_rules}}`

## When this command applies

Use this for governed changes to rule-shaping artifacts (templates, vocabulary schema, manifests).

## Truth sources

- `meta/*` governed source
- `.now/src/commit-to-meta.sh`
- `.now/src/check-meta-consistency.sh`

## Preconditions

- You can explain why this is a rule/governance change instead of ordinary content work.

## Steps

1. Edit declared governed files in `meta/`.
2. Commit declared paths with `.now/src/commit-to-meta.sh`.
3. Stage resulting gitlink on `now` (helper does this).
4. Commit `now` side through governed flow.

## Verification

- Declared paths only were committed on `meta`.
- `now` index includes updated `meta` gitlink.

## Failure protocol

- If helper reports undeclared dirty meta paths, clean or isolate them before retry.

## Evidence to report

- Meta SHA, now commit SHA, and declared path list.
CHANGE_RULES_TEMPLATE
)
    add_entry 100644 "$_blob" "stance/commands/change-rules.md.template"

    _blob=$(blob <<'SAVE_TEMPLATE'
---
description: "Save current stance state and summarize evidence for continuation"
---
<!-- generated-by: install-stance -->

# `/{{commands.save}}`

## When this command applies

Use this before handoff or context switch.

## Truth sources

- latest accepted commit(s)
- current checker status
- current `STANCE.md` vocabulary

## Preconditions

- Current cycle state has been classified.

## Steps

1. Capture the current `{{stance.floor}}`.
2. Capture the active `{{stance.claim}}`.
3. Capture next `{{stance.experiment}}` or explicit `{{stance.blocked}}`.
4. Record any must-run verification command for the next operator.

## Verification

- A new operator can resume without inferring missing mechanism.

## Failure protocol

- If context is incomplete, mark as `{{stance.blocked}}` and list missing evidence.

## Evidence to report

- Short continuation record with explicit floor/claim/experiment/blocked values.
SAVE_TEMPLATE
)
    add_entry 100644 "$_blob" "stance/commands/save.md.template"

    _tree=$(write_temp_tree)
    _parent=$(git rev-parse refs/heads/meta)
    _commit=$(git commit-tree "$_tree" -p "$_parent" -m "Initialize meta branch")
    git update-ref refs/heads/meta "$_commit"
    echo "  meta -> $_commit"
fi

# ===================================================================
# Step 7/8: Seed planning files
# ===================================================================

if ! step7_done; then
    echo "Step 7/8: Seeding planning files..."

    # Start from the current now tree (includes skeleton from step 5)
    read_into_temp "refs/heads/now^{tree}"

    # Pin meta submodule (gitlink to seeded meta tip from step 6)
    _meta_tip=$(git rev-parse refs/heads/meta)
    add_entry 160000 "$_meta_tip" "meta"

    # requirements.md
    _blob=$(blob <<'REQUIREMENTS'
## Protocol Header
- **Purpose:** requirements authority.
- **Authority:** requirements only.
- **Must contain:** problem statement, goals, non-goals, design principles, acceptance criteria, open issues, normative requirement statements.
- **Must not contain:** implementation details, symbol sketches, import graphs, module trees, execution order, node breakdown, commit protocol.
- **Update rule:** edit only when requirements change.

## Status
Draft
REQUIREMENTS
)
    add_entry 100644 "$_blob" "plan/requirements.md"

    # decisions.md
    _blob=$(blob <<'DECISIONS'
## Protocol Header
- **Purpose:** technical design for satisfying `requirements.md`.
- **Authority:** design choices only.
- **Must contain:** module placement, import graph, symbol sketches, constructive-definition choices, compatibility strategy, tradeoffs.
- **Must not contain:** execution order, active-task instructions, completion history.
- **Update rule:** edit when technical design changes.

## Status
Draft
DECISIONS
)
    add_entry 100644 "$_blob" "plan/decisions.md"

    # roadmap.md
    _blob=$(blob <<'ROADMAP'
## Protocol Header
- **Purpose:** execution sequencing for satisfying `requirements.md` and `decisions.md` in small, auditable chunks.
- **Authority:** sequencing and integration strategy only.
- **Must contain:** work chunks, dependencies, output files, validation gates, stress tests, audit hooks, exit criteria.
- **Must not contain:** new requirements, retrospective completion history, commit logs, prose replacing `requirements.md` or `decisions.md`.
- **Update rule:** edit when sequencing, chunk boundaries, file targets, or validation strategy changes.

## Status
Draft
ROADMAP
)
    add_entry 100644 "$_blob" "plan/roadmap.md"

    # continuation.md
    _blob=$(blob <<'CONTINUATION'
# Continuation — Single Current Task

## Protocol
- **Purpose:** the only active task for the current dispatch.
- **Authority:** current-task execution only.
- **Must contain:** one roadmap node ID, why now, dependencies, output files, local context, scope boundary, success condition, verification, stress test, audit target.
- **Must not contain:** multiple queued tasks, backlog items, roadmap-wide planning, long history.
- **Update rule:** after each commit, update this file to reflect the current active task state.
- **Update rule:** replace this file with the next single task only when the current task is completed or intentionally split.
- **Update rule:** if unfinished and still the same task, keep the same node ID and refresh only the local context/state as needed.
CONTINUATION
)
    add_entry 100644 "$_blob" "plan/continuation.md"

    # completion-log.md
    _blob=$(blob <<'COMPLETIONLOG'
# Completion Log

## Protocol Header
- **Purpose:** compact continuity ledger of material continuation transitions and handoff checkpoints.
- **Authority:** append-only continuation-transition log.
- **Must contain:** one line per material continuation transition or handoff checkpoint with date, node/slice ID, event, optional ref, brief accomplishment.
- **Must not contain:** long prose, design rationale, future planning, tiny intra-continuation fixes, pass-only notes.
- **Update rule:** append exactly one line when the active continuation materially changes or a real handoff checkpoint is created; never mutate prior lines.

Format:
`YYYY-MM-DD | <node-or-slice-id> | <event> | <optional-short-hash> | <brief accomplishment>`

## Log
COMPLETIONLOG
)
    add_entry 100644 "$_blob" "plan/completion-log.md"

    _tree=$(write_temp_tree)
    _parent=$(git rev-parse refs/heads/now)
    _commit=$(git commit-tree "$_tree" -p "$_parent" -m "Seed planning files and pin meta submodule")
    git update-ref refs/heads/now "$_commit"
    echo "  planning files -> $_commit"
fi

# ===================================================================
# Step 8/8: Checkout now
# ===================================================================

echo "Step 8/8: Checking out now..."
git checkout now

echo ""
echo "Initialization complete."
echo "Next step: ./bootstrap.sh"
