## Commands

Two packages: `packages/league_engine` (pure Dart) and `app` (Flutter, via `.fvmrc`).

- run: `./run.sh`
- test: `(cd packages/league_engine && dart test --reporter=compact) && (cd app && flutter test -j 1 --reporter=compact)`
- test-changed: `scripts/test_changed.sh`
- lint: `(cd packages/league_engine && dart analyze --fatal-infos) && (cd app && flutter analyze --fatal-infos)`
- coverage: `(cd packages/league_engine && dart test --reporter=compact --coverage=coverage --branch-coverage && dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib --check-ignore)`
- coverage-gaps: `coverage-gaps packages/league_engine/coverage/lcov.info`
