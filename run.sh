#!/bin/bash

# ============================================================================
# Install everything betting-sim needs, then run the game.
#
# One command, from a clean checkout to a playable window. The Linux desktop
# target is a Chrome-wrapped WEB build, not the GTK embedder, so Chrome is a
# real dependency here rather than a nicety.
#
# The debug build is the interesting one: it carries the balance-tuning panel
# (book awareness, margin, strength scale, fatigue penalty) with running ROI
# and CLV. `--release` builds without it, which is the shipping configuration.
#
# Usage:
#   ./run.sh              # play it, debug build, tuning panel visible
#   ./run.sh --release    # the shipping build, no tuning panel
#   ./run.sh --gates      # run every gate instead of playing
#   ./run.sh --engine     # headless: just the acceptance numbers
# ============================================================================

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO
readonly APP="$REPO/app"
readonly ENGINE="$REPO/packages/league_engine"

MODE="play"
FLAVOUR="debug"

usage() {
    sed -n '4,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
}

# Installs a pacman package if the command it provides is missing.
require_pacman() {
    local command_name="$1" package="$2"
    if command -v "$command_name" >/dev/null 2>&1; then
        return 0
    fi
    echo "Installing $package (provides '$command_name')..."
    sudo pacman -S --needed --noconfirm "$package"
}

validate_requirements() {
    if [[ ! -d "$APP" || ! -d "$ENGINE" ]]; then
        echo "Error: run this from the betting-sim checkout." >&2
        exit 1
    fi

    require_pacman flutter flutter-bin
    require_pacman jq jq

    # The web build needs a browser to launch into, and `flutter run -d chrome`
    # finds it through CHROME_EXECUTABLE. Both binaries here are already
    # wrappers on this machine; the fallback keeps a fresh box working.
    if [[ -z "${CHROME_EXECUTABLE:-}" ]]; then
        local browser
        for browser in google-chrome chromium chromium-browser; do
            if command -v "$browser" >/dev/null 2>&1; then
                CHROME_EXECUTABLE="$(command -v "$browser")"
                export CHROME_EXECUTABLE
                break
            fi
        done
    fi
    if [[ -z "${CHROME_EXECUTABLE:-}" ]]; then
        echo "Installing ungoogled-chromium-bin (no browser found)..."
        sudo pacman -S --needed --noconfirm ungoogled-chromium-bin
        CHROME_EXECUTABLE="$(command -v chromium)"
        export CHROME_EXECUTABLE
    fi
    echo "Browser: $CHROME_EXECUTABLE"
}

fetch_dependencies() {
    echo "Fetching engine dependencies..."
    (cd "$ENGINE" && dart pub get)
    echo "Fetching app dependencies..."
    (cd "$APP" && flutter pub get)
}

run_engine() {
    echo "============================================================"
    echo "The acceptance gate (headless, no UI)"
    echo "============================================================"
    bash "$REPO/scripts/check_acceptance.sh" "${1:-150}"
}

run_gates() {
    echo "== engine: analyze =="
    (cd "$ENGINE" && dart analyze --fatal-infos)
    echo "== engine: format =="
    (cd "$ENGINE" && dart format --output=none --set-exit-if-changed .)
    echo "== engine: test + coverage =="
    (cd "$ENGINE" && dart test --coverage=coverage --branch-coverage >/dev/null)
    (cd "$ENGINE" \
        && dart pub global run coverage:format_coverage --lcov --in=coverage \
            --out=coverage/lcov.info --report-on=lib --check-ignore \
        && bash "$REPO/scripts/check_coverage.sh" coverage/lcov.info)
    echo "== engine: RNG parity =="
    bash "$REPO/scripts/check_rng_parity.sh"
    echo "== app: analyze =="
    (cd "$APP" && flutter analyze --fatal-infos)
    echo "== app: format =="
    (cd "$APP" && dart format --output=none --set-exit-if-changed lib test)
    echo "== app: test =="
    (cd "$APP" && flutter test)
    echo "== 250-line cap =="
    bash "$REPO/scripts/check_file_length.sh" --all
    echo "== the tuning panel does not ship =="
    bash "$REPO/scripts/check_debug_absent.sh"
    echo "== acceptance gate =="
    run_engine 150
    echo "All gates passed."
}

run_game() {
    echo "============================================================"
    echo "betting-sim -- $FLAVOUR build"
    if [[ "$FLAVOUR" == "debug" ]]; then
        echo "The balance-tuning panel is at the bottom of the screen."
        echo "Moving any knob restarts the season: it changes pricing."
    else
        echo "Release build: no tuning panel, by design."
    fi
    echo "Press 'q' in this terminal to quit."
    echo "============================================================"
    cd "$APP"
    flutter run -d chrome "--$FLAVOUR"
}

main() {
    validate_requirements
    fetch_dependencies

    case "$MODE" in
        engine) run_engine ;;
        gates) run_gates ;;
        *) run_game ;;
    esac
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --release) FLAVOUR="release"; shift ;;
        --profile) FLAVOUR="profile"; shift ;;
        --gates) MODE="gates"; shift ;;
        --engine) MODE="engine"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

main "$@"
