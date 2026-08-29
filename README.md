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

## Watching the games

A match is not a number appearing any more. Once a round is played you can
watch any of it back: a running clock, goals with the scorer named, bookings,
dismissals, injuries, and a full box score at the whistle -- shots, how many
came after the break, shots on target, corners, fouls, cards and possession.

Every one of those numbers answers to **exactly one** hidden factor, so they
can be read apart rather than admired. Fatigue dries up a side's attempts
after the hour; form moves how many attempts are on target; morale widens the
possession spread without moving its mean; injuries put names on the missing
list; the referee decides fouls and cards and touches nothing else. Corners
answer to nothing hidden at all.

Watching cannot change what happened -- the round was decided when you played
it, and the report is regenerated from the same seed. See
`DOCS-architecture.md` for why that ordering is load-bearing.

Headless, for one match:

```sh
cd packages/league_engine
dart run bin/watch.dart 20260828 3 2     # seed, matchday, fixture
```

## The internet

Twelve people post about every fixture, with names, standing biases and a
tone. Two of them genuinely know more than the price. The rest are reading the
odds back to you, and three are worse than useless.

Nothing marks which is which. How loudly somebody states an opinion is drawn
independently of whether they are right, so the feed cannot be read at a
glance -- the only way to find the two worth following is to write down what
they said and check later, which the app does for you under "your records".
It ranks by what a flat stake would have RETURNED, not by how often they were
right: a tipster who only ever backs odds-on favourites is right most weeks
and still loses you money.

All of it is invented and generated from the seed tree. There is no network
call anywhere in the app.

```sh
cd packages/league_engine
dart run bin/feed.dart 20260828 4 0     # seed, matchday, fixture
```

## Your friends

Six people you know, each with a standing idea about football -- one chases
favourites, one only wants the big price, one backs their club until they die,
one thinks everything is a 1-1. Every save has at least one of each, so no
circle is quietly unplayable.

They offer you bets. THEY back something, you lay it: if their pick comes in
you owe them, and if it does not you keep their stake. There is no margin in
the price, because a friend is not a smaller bookmaker -- which is why the
only reason to take one is that you think they are wrong.

Three things you can do: take it, leave it, or haggle. Haggling is a real
decision rather than a free reroll, because a stubborn friend simply walks and
the bet is gone. What you cannot see is how far each of them will move, and
the only way to learn it is to try.

## The week around it

The matches are on Saturday. The other six days are yours, and they are where
the stakes live: twenty-four hours to divide between a shift, sleep, meals,
and reading up on the football. An hour spent working is an hour not spent on
the feed, and the rent does not care which you picked.

Rent comes out every Friday. Miss it twice and you are put out, and that is
the run -- the bankroll finally has a floor you can fall through. Working full
time keeps a roof on and very little else; getting anywhere means the betting.

Run yourself into the ground and the wages stop: once you give out, the rest
of that shift is gone, because an hour's kip does not put you back on the
floor. Skipping sleep to read one more preview is a real decision.

The shop sells four things and all of them are hours: a bicycle, a slow
cooker, a decent telly, a chair that does not hurt. Nothing in it improves a
price. Selling the edge would sell the only thing the game is about.

## Acceptance gate

The engine is not finished until a headless batch prints ten numbers. The
first four are about the bookmaker:

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
