# Architecture

```
packages/league_engine/   pure Dart, zero Flutter imports, `dart run`-able
  rng/         the generator and the seed tree
  ratings/     Glicko-2
  league/      clubs, squads, fixtures, invented names
  latent/      the hidden state and how it reaches a match
  scoreline/   the pluggable match model
  book/        pricing, line movement, limits, CLV
  bettors/     random, oracle, skilled
  engine/      match runner, market maker, season runner
  acceptance/  metrics, gates, report
app/           Flutter — Android native, Linux via Chrome-wrapped web
```

## The engine knows nothing about Flutter

`league_engine` has no Flutter dependency and no I/O. It runs headless under
`dart test` and `dart run`, which is what lets the acceptance gate simulate
hundreds of seasons in seconds and what keeps the UI from ever drifting from
the simulation the gate measures. `GameState` in the app holds no simulation
logic at all — it delegates.

## Pricing and playing are separate

`ScorelineModel` has exactly two methods:

- `outcomeProbabilities(ctx)` — **pure, no RNG**. The bookmaker prices from it.
- `simulate(ctx, rng)` — **all** randomness arrives via `rng`.

The split is load-bearing. If quoting odds consumed the match's randomness, the
act of pricing would perturb the scoreline being priced, and replay would
break. A possession-based engine for a second sport satisfies the same
interface by Monte-Carlo-ing its own probabilities from a separate sub-seed.

The two must also **agree**. `simulate` samples from the same Dixon-Coles-
corrected grid that `outcomeProbabilities` integrates; an earlier version drew
two independent Poissons and quietly disagreed with its own prices by 1.4pp on
draws. A book that quotes one distribution and settles another is a book whose
odds are a lie, so a convergence test pins them together at a 0.006 tolerance.

## Hidden state is genuinely hidden

Fatigue, morale, form, injuries, weather and referee bias perturb how a club
performs. Only weather is shown. Everything else leaks solely through noisy box
scores and results, which is the game: reading the hidden state from the
observable record.

Each factor is given a **distinct statistical fingerprint** so a diligent
player can tell them apart. If two hidden factors moved the same observable the
same way, no amount of study could separate them:

| factor | fingerprint |
| ------ | ----------- |
| fatigue | lower scoring **and** goals arriving earlier |
| morale | wider spread of results, mean unchanged |
| form | a small mean shift that decays |
| injuries | a step change in scoring, against team news |

Morale's attack multiplier is exactly 1.0000 at every level; only its variance
multiplier moves. Tests assert this directly.

`LatentModifiers` is the only route from hidden state into a match, so the
values cannot leak into scoring by accident.

## Saves are a seed plus deltas

A save is a master seed and a stream of typed `MatchEvent`s, never a snapshot.
That makes saves small enough to sync between a phone and a desktop, and it is
why the RNG work in `DOCS-seeding.md` is load-bearing rather than incidental.

Sub-seeds are **O(1) addressable**: match `(season, day, match)` is reachable
without simulating anything before it. A test simulates a whole 380-match
season, rebuilds one match from its seed path, and asserts `simulate` was
called exactly once — the difference between "replay works" and "replay
secretly re-runs the universe".

Pricing and playing draw from disjoint sub-seeds (`possession: 0` for
pre-match weather and referee, `1` for the match, `2` for the book, `3` for the
bettor), so no part can disturb another.

## The book is deliberately fallible

`MarketMaker` prices a **partially latent-blind** view of each fixture rather
than the truth. This has to be constructed explicitly: pricing `truth + noise`
would already embed fatigue and form perfectly, leaving nothing to know, and a
bettor correcting for them would be double-counting.

How blind it is decides the whole game's balance. See `DOCS-acceptance-gate.md`.
