# Continuation — Single Current Task

## Protocol

- **Purpose:** the only active task for the current dispatch.
- **Authority:** current-task execution only.
- **Must contain:** one roadmap node ID, why now, dependencies, output files, local context, scope boundary, success condition, verification, stress test, audit target.
- **Must not contain:** multiple queued tasks, backlog items, roadmap-wide planning, long history.
- **Update rule:** after each commit, update this file to reflect the current active task state.
- **Update rule:** replace this file with the next single task only when the current task is completed or intentionally split.
- **Update rule:** if unfinished and still the same task, keep the same node ID and refresh only the local context/state as needed.

## Task Identity

- **Node ID:** GT16
- **Title:** Hardening, split policy, and first-release cut
- **Status:** DONE

## Completion Summary

GT16 delivered all four deliverables:

1. **KNOWN-LIMITATIONS.md** — documents platform requirements (POSIX shell, git 2.38+), local-only enforcement, manual installation, no past/future tooling, no multi-remote support, now-branch serialization, open design decisions, and test coverage scope.
2. **Split policy** — added to `plan/decisions.md` §"Split policy for roadmap nodes". Covers triggers, child ID naming, acceptance narrowing, DAG updates, continuation updates, and interstitial node policy.
3. **Version tag criteria** — added to `plan/roadmap.md`. Five falsifiable conditions: all nodes complete, all tests pass, limitations documented, no enforcement regression, README current. Tag format specified.
4. **Release summary** — added "Requirements" and "What's included" sections to `README.md` with link to KNOWN-LIMITATIONS.md.

## What's next

The initial roadmap (GT0–GT16) is complete. No continuation task is queued. Future work would begin with a new roadmap node (GT17+) following the split policy and interstitial node conventions documented in `plan/decisions.md`.
