#!/bin/bash

# ============================================================================
# Run the acceptance gate and fail if any gate does not hold.
#
# This is the project's stop-the-world condition: the engine is worthless if it
# is not LEARNABLE, and these are the numbers that decide it.
#
#   gate 1   skill pays over a season (mean season ROI, CI excludes zero)
#   gate 2   one night is a coin flip (median matchday ROI, losing fraction)
#   gate 3a  the book charges exactly its margin, against a perfect book
#   gate 3b  chance loses, and skill beats chance, in the live market
#
# Usage:
#   scripts/check_acceptance.sh [seasons] [masterSeed]
# ============================================================================

set -euo pipefail

readonly SEASONS="${1:-200}"
readonly MASTER_SEED="${2:-9000}"

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../packages/league_engine" && pwd)"
readonly PKG

main() {
    local output
    output="$(cd "$PKG" && dart run bin/acceptance.dart "$SEASONS" "$MASTER_SEED")"
    echo "$output"

    if ! grep -q '^ALL GATES PASSED$' <<<"$output"; then
        echo "" >&2
        echo "Acceptance gate FAILED. Nothing downstream should be built" >&2
        echo "until the engine is learnable again." >&2
        exit 1
    fi
}

main "$@"
