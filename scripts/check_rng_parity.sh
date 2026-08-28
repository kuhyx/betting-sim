#!/bin/bash

# ============================================================================
# Fail if the engine's RNG diverges between the Dart VM and JavaScript.
#
# The app ships to Android (native, 64-bit ints) and to a Chrome-wrapped web
# build (JS numbers: doubles, exact to 53 bits). Saves are a seed plus event
# deltas, so a one-bit disagreement means a game synced from the phone replays
# differently on the desktop -- silently, and only for some matches.
#
# This is why the engine owns a 32-bit generator instead of using dart:math or
# a 64-bit mixer: `dart compile js` rejects 64-bit literals outright.
# ============================================================================

set -euo pipefail

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../packages/league_engine" && pwd)"
readonly PKG
readonly PROBE="tool/cross_platform_rng.dart"

TEMP_DIR=""
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

main() {
    TEMP_DIR="$(mktemp -d)"

    local vm_out js_out
    vm_out="$(cd "$PKG" && dart run "$PROBE")"

    (cd "$PKG" && dart compile js -O2 -o "$TEMP_DIR/probe.js" "$PROBE" >/dev/null)
    js_out="$(node "$TEMP_DIR/probe.js")"

    if [[ "$vm_out" != "$js_out" ]]; then
        echo "RNG parity FAILED: the VM and JavaScript disagree." >&2
        diff <(echo "$vm_out") <(echo "$js_out") >&2 || true
        exit 1
    fi

    echo "RNG parity OK: VM and JavaScript agree on every seed and draw."
}

main "$@"
