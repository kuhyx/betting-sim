#!/bin/bash

# ============================================================================
# Build the release web bundle that itch.io serves.
#   scripts/export_web.sh [out_dir]   (default: ../betting-sim_binaries/web)
#
# Two differences from a plain `flutter build web`, both because itch serves
# the game from a sub-path inside an iframe on a different origin:
#   - CanvasKit is bundled (--no-web-resources-cdn) rather than fetched from
#     gstatic, so the game does not depend on a third-party CDN being
#     reachable from inside itch's sandbox.
#   - <base href="/"> becomes "./". Flutter refuses a relative --base-href,
#     and an absolute "/" resolves every asset against html.itch.zone's root,
#     where none of them exist.
# ============================================================================

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO
readonly OUT="${1:-$REPO/../betting-sim_binaries/web}"

main() {
    (cd "$REPO/app" && flutter pub get >/dev/null \
        && flutter build web --release --no-web-resources-cdn --output "$OUT")
    sed -i 's|<base href="/">|<base href="./">|' "$OUT/index.html"
    if ! grep -q '<base href="./">' "$OUT/index.html"; then
        echo "Error: could not make <base href> relative in $OUT/index.html" >&2
        exit 1
    fi
    echo "OUT=$(cd "$OUT" && pwd)"
}

main "$@"
