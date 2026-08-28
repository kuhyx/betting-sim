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
tools/balance/            throwaway balancing harness, never shipped
```

## Running

```sh
cd packages/league_engine
dart pub get
dart test
```

## Gates

All of these run in CI and must pass:

```sh
dart analyze --fatal-infos          # no lint suppressions without asking
dart test --coverage=coverage       # 100% coverage is the bar
scripts/check_coverage.sh <lcov>    # fails closed, never warns
scripts/check_rng_parity.sh         # VM and JavaScript must agree bit for bit
scripts/check_file_length.sh --all  # 250 lines, code and prose
```

The RNG parity gate is the unusual one. See `DOCS-seeding.md`.
