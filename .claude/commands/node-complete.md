Mark a roadmap node as complete: update the roadmap, append to the completion log, and advance the continuation file.

## Context

Completing a roadmap node requires updating three planning files:

1. **`plan/roadmap.md`** — update the node's status note to "Complete" (or add a completion status)
2. **`plan/completion-log.md`** — append an entry recording what was done (append-only ledger)
3. **`plan/continuation.md`** — replace with the next task, or clear if no successor is queued

The completion log format follows the existing entries: date, node ID, brief description of what was delivered.

## Arguments

$ARGUMENTS — `<node-id> ["<completion-summary>"]`

Example: `GT17 "Implemented multi-remote support with full test coverage"`

If no node ID is provided, read `plan/continuation.md` to find the current active task and use that.
If no summary is provided, ask the user for a one-sentence description of what was delivered.

## What to do

1. **Identify the node** — from $ARGUMENTS or from `plan/continuation.md`'s current Task Identity.

2. **Read the current state** of all three planning files.

3. **Validate completion**:
   - Ask the user to confirm: "Are all acceptance criteria for <ID> met? (y/n)"
   - If the node has validation gates (test suites, smoke scripts), remind the user to run them before marking complete.

4. **Update `plan/roadmap.md`**:
   - Find the node's section and add or update its status line to: `- **Status:** Complete`
   - If the node is the last in the "Completion status" section, update the section summary.

5. **Append to `plan/completion-log.md`**:
   - Follow the existing format (read a few existing entries to match style).
   - Add entry: `<date> | <node-id> | <title> | <summary>`
   - Use today's date.

6. **Update `plan/continuation.md`**:
   - Read the current file to understand the next queued task (if any).
   - If a successor node is identifiable (from the DAG in roadmap.md), populate continuation.md with that next node.
   - If no successor exists, update continuation.md to reflect "No continuation queued. Future work begins with a new roadmap node."
   - Follow the exact protocol header format established in the file.

7. **Commit all three files** together:
   - Commit message: `complete <node-id>: <title>`

8. **Report**: node marked complete, log entry added, continuation updated to <next-node-id or "none">.
