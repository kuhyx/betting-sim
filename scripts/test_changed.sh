#!/bin/bash

# ============================================================================
# Run only the tests related to files changed vs HEAD (staged, unstaged and
# untracked). Quiet: failures plus a one-line summary. Two packages:
# packages/league_engine (dart test) and app (flutter test). A package falls
# back to its full suite when a change cannot be mapped to a test file.
# ============================================================================

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
CHANGED=()
while IFS= read -r f; do
    [[ -n "$f" && -e "$f" ]] && CHANGED+=("$f")
done < <({ git diff --name-only HEAD 2>/dev/null || true; git ls-files --others --exclude-standard; } | sort -u)

readonly ENGINE="packages/league_engine"
readonly APP="app"

# Per package: full=1 when unmappable, tests[] holds package-relative test files.
engine_full=0 app_full=0 engine_touched=0 app_touched=0
engine_tests=() app_tests=()

# Map a package-relative lib file to its test file(s); sets MAPPED (array).
map_lib() {
    local pkg="$1" rel="$2" base cand
    MAPPED=()
    base="$(basename "${rel%.dart}")"
    cand="test/${rel#lib/}"
    cand="${cand#src/}"
    cand="${cand%.dart}_test.dart"
    if [[ -f "$pkg/$cand" ]]; then MAPPED+=("$cand"); return; fi
    while IFS= read -r t; do MAPPED+=("${t#"$pkg"/}"); done < <(git ls-files "$pkg/test/*${base}_test.dart")
}

for f in "${CHANGED[@]}"; do
    case "$f" in
        "$ENGINE"/pubspec.* | "$ENGINE"/analysis_options.yaml) engine_full=1; engine_touched=1 ;;
        "$ENGINE"/test/*_test.dart) engine_touched=1; engine_tests+=("${f#"$ENGINE"/}") ;;
        "$ENGINE"/lib/*.dart)
            engine_touched=1
            map_lib "$ENGINE" "${f#"$ENGINE"/}"
            if [[ ${#MAPPED[@]} -gt 0 ]]; then engine_tests+=("${MAPPED[@]}"); else engine_full=1; fi
            ;;
        "$ENGINE"/*.dart) engine_touched=1; engine_full=1 ;;
        "$APP"/pubspec.* | "$APP"/test/flutter_test_config.dart) app_full=1; app_touched=1 ;;
        "$APP"/test/*_test.dart) app_touched=1; app_tests+=("${f#"$APP"/}") ;;
        "$APP"/lib/*.dart)
            app_touched=1
            map_lib "$APP" "${f#"$APP"/}"
            if [[ ${#MAPPED[@]} -gt 0 ]]; then app_tests+=("${MAPPED[@]}"); else app_full=1; fi
            ;;
    esac
done

rc=0
run_pkg() {
    local dir="$1" full="$2"; shift 2
    local runner="$1"; shift
    if [[ "$full" -eq 1 || $# -eq 0 ]]; then
        echo "$dir: running full suite"
        (cd "$dir" && "$runner" test -j 1 --reporter=compact) || rc=1
    else
        echo "$dir: $# test file(s)"
        (cd "$dir" && "$runner" test -j 1 --reporter=compact "$@") || rc=1
    fi
}

if [[ $engine_touched -eq 0 && $app_touched -eq 0 ]]; then
    echo "no engine/app dart changes vs HEAD: nothing to test"; exit 0
fi
if [[ $engine_touched -eq 1 ]]; then
    mapfile -t uniq_e < <(printf '%s\n' "${engine_tests[@]}" | sort -u | sed '/^$/d')
    run_pkg "$ENGINE" "$engine_full" dart "${uniq_e[@]}"
fi
if [[ $app_touched -eq 1 ]]; then
    mapfile -t uniq_a < <(printf '%s\n' "${app_tests[@]}" | sort -u | sed '/^$/d')
    run_pkg "$APP" "$app_full" flutter "${uniq_a[@]}"
fi
[[ $rc -eq 0 ]] && echo "test-changed: pass" || echo "test-changed: FAIL"
exit $rc
