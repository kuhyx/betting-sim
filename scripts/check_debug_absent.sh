#!/bin/bash

# ============================================================================
# Fail unless the debug tuning surface is absent from a RELEASE web build.
#
# The balance knobs let a player rewrite the game's difficulty, so they must
# not ship. `kDebugMode` is const-folded by the compiler and the dead branch is
# tree-shaken, but "should be" is not a gate -- this asserts it on the actual
# artifact.
#
# The check runs BOTH WAYS on purpose. Grepping only the release build makes a
# typo in the canary an automatic pass: a string that is spelled wrong is
# absent from every build, and the gate would congratulate itself. So the same
# canary must also be found PRESENT in a debug build, which proves the search
# string is real and the grep works.
#
# Usage:
#   scripts/check_debug_absent.sh
# ============================================================================

set -euo pipefail

APP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../app" && pwd)"
readonly APP

# Must match `debugPanelTitle` in app/lib/ui/debug_panel.dart. A UI-only
# string, deliberately: an engine field name such as `bookLatentAwareness`
# ships in release regardless and would prove nothing.
readonly CANARY='BALANCE TUNING (debug only)'

readonly RELEASE_DIR="build/web-release-gate"
readonly DEBUG_DIR="build/web-debug-gate"

cleanup() {
    rm -rf "${APP:?}/$RELEASE_DIR" "${APP:?}/$DEBUG_DIR"
}

trap cleanup EXIT

# Greps every compiled artifact in a build directory for the canary.
canary_in() {
    local dir="$1"
    grep -rqF "$CANARY" "$APP/$dir"
}

main() {
    cd "$APP"

    echo "Building release web bundle..."
    flutter build web --release --output "$RELEASE_DIR" >/dev/null

    echo "Building debug web bundle..."
    flutter build web --debug --output "$DEBUG_DIR" >/dev/null

    # Positive control: if the canary is not in the DEBUG build either, the
    # search string is wrong and the release result below is meaningless.
    if ! canary_in "$DEBUG_DIR"; then
        echo "Error: canary not found in the DEBUG build." >&2
        echo "       The search string no longer matches debugPanelTitle," >&2
        echo "       so this gate cannot prove anything. Fix the canary." >&2
        exit 1
    fi
    echo "OK: canary present in the debug build (the grep works)."

    if canary_in "$RELEASE_DIR"; then
        echo "" >&2
        echo "FAILED: the debug tuning surface is present in a RELEASE" >&2
        echo "        build. The balance knobs must not ship." >&2
        grep -rlF "$CANARY" "$RELEASE_DIR" >&2
        exit 1
    fi

    echo "OK: canary absent from the release build."
    echo "Debug-surface gate OK: the tuning panel does not ship."
}

main "$@"
