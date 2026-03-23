Add a new roadmap node to plan/roadmap.md.

## Context

The Temporal Membrane uses a structured roadmap in `plan/roadmap.md` with nodes that follow strict conventions:

**Node kinds:**
- **Q** — resolve an open design question, update design docs
- **C** — implement and validate a capability with acceptance criteria
- **H** — harden, package, or demonstrate an already-implemented capability

**Per-node required fields:** work chunk, dependencies, output files, validation gates, exit criteria.

**Naming:** nodes use prefix + sequential ID (e.g., `GT17`, `GT18`). The prefix matches the project's established pattern — check existing nodes to determine it.

## Arguments

$ARGUMENTS — `<id> "<title>" [<kind>] [<depends-on>...]`

Example: `GT17 "Multi-remote support" C GT16`

If arguments are incomplete or absent, ask the user for:
1. Node ID (suggest the next sequential ID based on existing nodes)
2. Title
3. Kind (Q/C/H)
4. Dependencies (which existing nodes must complete first)
5. Brief description of the goal

## What to do

1. **Read `plan/roadmap.md`** to understand the existing node structure, the last node ID, and the DAG.

2. **Determine the new node ID** — if not provided in $ARGUMENTS, find the highest existing node number and suggest the next one.

3. **Prompt for missing fields** if $ARGUMENTS is incomplete.

4. **Draft the node** following the template pattern:
   ```markdown
   ### <ID> — <Title>
   - **Kind:** <Q|C|H>
   - **Depends on:** <deps or "none">
   - **Goal:** <one sentence>
   - **Deliverables:**
     - <list>
   - **Acceptance:**
     - <falsifiable criteria>
   - **Status note:** In progress
   ```

5. **Update the DAG** — add the new node's dependency edges to the `## DAG overview` section.

6. **Insert the node** into `plan/roadmap.md` after the last existing node (before the "Suggested critical path" section if present, or at the end of the Nodes section).

7. **Update `plan/continuation.md`** — if there is no active task queued, set this new node as the current task:
   - Fill in Node ID, Title, status "In progress", dependencies, and a brief description of local context.

8. **Commit** the changes on `now` (or whatever branch holds the planning files):
   - Commit message: `plan: add roadmap node <ID> — <title>`

9. **Report** the new node ID and its position in the DAG.
