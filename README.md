# betting-sim

A sports-betting simulator with a **fictional** sport, fictional teams and
fictional money — closer to a fake stock-market simulator than to a casino app.
There is no real-money path and nothing to cash out.

## The one idea

The league underneath must be a **genuine simulation with inferable hidden
state**, not RNG behind cosmetic odds. Pure RNG is an unlearnable slot machine:
there is nothing to get good at, so there is no game. Here the true win
probability exists but is hidden; the book prices its own estimate and adds a
margin; a player wins by estimating better than the book on some subset of
matches, and by betting only when the edge exceeds that margin.

## Acceptance gate

The engine is not finished until a headless batch prints three numbers:

1. **Skill pays over a season** — mean ROI positive, 95% CI excludes zero.
2. **One night is a coin flip** — median matchday ROI ≤ 0, losing nights in
   [0.45, 0.55].
3. **A random bettor bleeds the vig** — mean ROI converges to `−v/(1+v)`.

Gate 2 is deliberately about *variance*, not expectation. EV is linear in bets,
so a strategy cannot be +EV over a season and −EV over one night; if a build
shows a negative per-night expectation, the bookmaker has a bug.

## Layout

```
packages/league_engine/   pure Dart, zero Flutter imports, `dart run`-able
app/                      Flutter — Android native, Linux via Chrome-wrapped web
```

See `DOCS-architecture.md` for how the pieces fit, `DOCS-seeding.md` for why
the engine owns its random number generator, and `DOCS-acceptance-gate.md` for
what the four gate numbers mean.

## Running

The engine, headless:

```sh
cd packages/league_engine
dart pub get
dart test
dart run bin/acceptance.dart 200 9000
```

The game:

```sh
cd app
flutter pub get
flutter run -d chrome      # desktop is a Chrome-wrapped web build
flutter run -d <device>    # Android
```

## Gates

All of these run in CI and must pass:

```sh
dart analyze --fatal-infos          # no lint suppressions without asking
dart test --coverage=coverage --branch-coverage
scripts/check_coverage.sh <lcov>    # 100% lines AND branches; fails closed
scripts/check_rng_parity.sh         # VM and JavaScript must agree bit for bit
scripts/check_file_length.sh --all  # 250 lines, code and prose
```

The RNG parity gate is the unusual one. See `DOCS-seeding.md`.
