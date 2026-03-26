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
    _output=$(git ls-tree "refs/heads/now" -- .now/hooks/ 2>/dev/null) || return 1
    [ -n "$_output" ]
}

step6_done() {
    _meta_tree=$(git rev-parse "refs/heads/meta^{tree}" 2>/dev/null) || return 1
    _empty_tree=$(git mktree </dev/null)
    [ "$_meta_tree" != "$_empty_tree" ]
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
    if [ ! -s "$TEMP_ENTRIES" ]; then
        echo "Error: .now/hooks/ and .now/src/ not found in HEAD." >&2
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
