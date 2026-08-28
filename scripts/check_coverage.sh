#!/bin/bash

# ============================================================================
# Fail unless every line in lib/ is covered.
#
# 100% is the standing bar, and it is reachable here precisely because the
# engine is deterministic: one seed drives one execution path, so a branch a
# test reaches once it reaches forever. Where seeding alone cannot steer into
# a branch, inject ScriptedRandomSource or override the config -- do not lower
# this threshold.
#
# Usage:
#   scripts/check_coverage.sh <lcov.info>
# ============================================================================

set -euo pipefail

readonly LCOV="${1:-}"

main() {
    if [[ -z "$LCOV" ]]; then
        echo "Usage: $(basename "$0") <lcov.info>" >&2
        exit 1
    fi
    if [[ ! -f "$LCOV" ]]; then
        echo "Error: coverage file not found: $LCOV" >&2
        exit 1
    fi

    local failed=0
    local total_found=0
    local total_hit=0

    # LCOV records: SF=source file, LF=lines found, LH=lines hit.
    while IFS= read -r line; do
        case "$line" in
            SF:*) file="${line#SF:}" ;;
            LF:*) found="${line#LF:}" ;;
            LH:*)
                hit="${line#LH:}"
                total_found=$((total_found + found))
                total_hit=$((total_hit + hit))
                if [[ "$hit" -ne "$found" ]]; then
                    echo "UNCOVERED  $file: $hit/$found"
                    failed=1
                fi
                ;;
        esac
    done < "$LCOV"

    if [[ "$total_found" -eq 0 ]]; then
        echo "Error: no coverage data found in $LCOV" >&2
        exit 1
    fi

    if [[ "$failed" -ne 0 ]]; then
        echo "Coverage gate FAILED: $total_hit/$total_found lines." >&2
        exit 1
    fi

    echo "Coverage gate OK: $total_hit/$total_found lines."
}

main "$@"
