#!/bin/sh
# check-composition.sh — Atomic cross-check evaluator.
#
# Runs the full constraint suite against the candidate composition:
#   1. Schema validation (validate-gitmodules.sh)
#   2. Past monotonicity (check-past-monotonicity.sh)
#   3. Future grounding (check-future-grounding.sh)
#   4. Meta self-consistency (check-meta-consistency.sh)
#
# All checks run regardless of earlier failures (reports all violations).
# Exit 0 only if all checks pass.
#
# Usage: check-composition.sh [path-to-gitmodules]
#   Must be run from the root of a git repository.
#
# Exit codes:
#   0 — all constraints satisfied
#   1 — one or more constraint violations
#   2 — usage error
#
# GT8c: Constraint engine v1 — atomic cross-check pass.

set -eu

GITMODULES="${1:-.gitmodules}"

if [ ! -f "$GITMODULES" ]; then
    echo "Error: file not found: $GITMODULES" >&2
    exit 2
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not in a git repository" >&2
    exit 2
fi

# Locate sibling check scripts.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEMA_CHECK="$SCRIPT_DIR/validate-gitmodules.sh"
MONOTONICITY_CHECK="$SCRIPT_DIR/check-past-monotonicity.sh"
GROUNDING_CHECK="$SCRIPT_DIR/check-future-grounding.sh"
META_CHECK="$SCRIPT_DIR/check-meta-consistency.sh"

for _check in "$SCHEMA_CHECK" "$MONOTONICITY_CHECK" "$GROUNDING_CHECK" "$META_CHECK"; do
    if [ ! -f "$_check" ]; then
        echo "Error: check script not found: $_check" >&2
        exit 2
    fi
done

failed=0

set +e

sh "$SCHEMA_CHECK" "$GITMODULES"
if [ $? -ne 0 ]; then
    failed=$((failed + 1))
fi

sh "$MONOTONICITY_CHECK" "$GITMODULES"
if [ $? -ne 0 ]; then
    failed=$((failed + 1))
fi

sh "$GROUNDING_CHECK" "$GITMODULES"
if [ $? -ne 0 ]; then
    failed=$((failed + 1))
fi

sh "$META_CHECK" "$GITMODULES"
if [ $? -ne 0 ]; then
    failed=$((failed + 1))
fi

set -e

if [ "$failed" -gt 0 ]; then
    echo "composition: $failed check(s) failed." >&2
    exit 1
fi

exit 0
