#!/bin/bash

# ============================================================================
# Publish the browser build to https://kuhyx.itch.io/betting-sim (channel
# "html5"): build, prove it boots in headless Chromium, then butler push.
# The upload is versioned with the git commit so itch shows which build is live.
#   tools/publish_itch.sh [--dry-run]
# Needs a one-time `butler login` (browser OAuth). Installs butler and uv if
# missing.
# ============================================================================

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO
readonly TARGET="kuhyx/betting-sim:html5"
readonly BUTLER_URL="https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default"
readonly BIN_DIR="$HOME/.local/bin"
readonly OUT="$REPO/../betting-sim_binaries/web"
DRY_RUN=0

ensure_butler() {
    command -v butler >/dev/null 2>&1 && return
    echo "Installing butler into $BIN_DIR..."
    local tmp
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/butler.zip" "$BUTLER_URL"
    unzip -q "$tmp/butler.zip" -d "$tmp"
    mkdir -p "$BIN_DIR"
    install -m 755 "$tmp/butler" "$BIN_DIR/butler"
    rm -rf "$tmp"
    butler --version
}

ensure_uv() {
    command -v uv >/dev/null 2>&1 && return
    echo "Installing uv..."
    sudo pacman -S --needed --noconfirm uv
}

main() {
    [[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1
    ensure_butler
    ensure_uv
    if [[ -n "$(git -C "$REPO" status --porcelain --untracked-files=no)" ]]; then
        echo "Error: uncommitted changes; publish a committed build only." >&2
        exit 1
    fi
    "$REPO/scripts/export_web.sh" "$OUT"
    uv run --with playwright python -m playwright install chromium >/dev/null
    uv run --with playwright python "$REPO/scripts/web_smoke.py" "$OUT" \
        --shot "$OUT/../web_smoke.png"
    local version
    version="$(git -C "$REPO" rev-parse --short HEAD)"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "dry run: would push $OUT to $TARGET as $version"
        return
    fi
    butler push "$OUT" "$TARGET" --userversion "$version"
    butler status "$TARGET" </dev/null
}

main "$@"
