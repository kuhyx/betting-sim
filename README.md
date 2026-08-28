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

Everything, in one command:

```sh
./run.sh              # installs what is missing, then plays it
./run.sh --release    # the shipping build: no tuning panel
./run.sh --gates      # every gate instead of the game
./run.sh --engine     # headless, just the acceptance numbers
```

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

## Tuning the balance while playing

A debug build carries a tuning panel under the fixture list: book awareness,
margin, strength scale and fatigue penalty, with running ROI and CLV for the
human player. `SeasonRunner.bookLatentAwareness` is measured against a
synthetic bettor; this is how it gets measured against a person.

Moving any knob **restarts the season** -- the knobs decide what the book
quotes, so every price already on screen was struck under the old value. The
master seed is carried across the restart on purpose: the same fixtures at a
different awareness is what makes a setting feelable rather than merely
different.

Two things worth knowing when reading the panel:

- **Matchday 1 always feels identical.** Every club starts at a zeroed
  `LatentState`, so there is no hidden state for the book to be blind to and
  the blend is a no-op. Fatigue and form need a few matchdays to accumulate
  before awareness has anything to bite on.
- **CLV moves before ROI does.** Over the handful of bets a human strikes in
  one sitting, ROI is almost entirely variance. CLV compares two prices and is
  readable far sooner.

The panel must never ship. `scripts/check_debug_absent.sh` asserts that on the
built artifact rather than trusting `kDebugMode` to fold, and asserts it BOTH
ways -- the canary must be found in a debug build too, so a mistyped search
string fails instead of silently passing.

## Gates

All of these run in CI and must pass:

```sh
dart analyze --fatal-infos          # no lint suppressions without asking
dart test --coverage=coverage --branch-coverage
scripts/check_coverage.sh <lcov>    # 100% lines AND branches; fails closed
scripts/check_rng_parity.sh         # VM and JavaScript must agree bit for bit
scripts/check_file_length.sh --all  # 250 lines, code and prose
scripts/check_debug_absent.sh       # the tuning panel is not in a release build
```

The RNG parity gate is the unusual one. See `DOCS-seeding.md`.
