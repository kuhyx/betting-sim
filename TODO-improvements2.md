# Part 2 — making it a game

REMOVE ME AFTER FINISH

## The complaint

The game is lacklustre. It misses:

1. browsing the internet for best bets — reading randoms' opinions on how
   teams perform
2. betting together with friends — accepting theirs, proposing yours,
   rejecting theirs
3. actually "watching"/"following" the games: specific players messing up or
   succeeding, obscure stats like corners, fouls, yellow cards. The games are
   not being simulated at all.
4. no life sim. You win or lose, but what of it? No work, nothing to spend
   money on, no consequence at bankroll 0, no stress, no sleep, no food, no
   items.

## Settled decisions

| decision | choice |
| -------- | ------ |
| new match stats | signal-carrying, one stat <- exactly one latent factor |
| friend-bet P&L | its own gate number (gate 4); gates 1-3 stay book-only |
| life sim | gating — time and money are budgets that limit betting |
| friends | simulated NPCs, seeded and replayable, never networked |
| the "internet" | fictional, generated from the seed tree. No real web. |

## Invariants

- **Watching never changes what happens.** Following a match selects which
  already-generated timeline you see. Time buys information, never a different
  outcome.
- **Cards never feed back into scoring.** The narrator runs after the score is
  sampled, so referee bias structurally cannot reach goals. Ten men winning
  3-0 is the price of the one-stat-one-factor rule, not a bug.

## Phases

- [x] **0 — shell**: navigation, calendar, local save
- [x] **1 — the match happens**: timeline, stats, players, on slots 4-17.
      Acceptance numbers stayed bit-identical; dixon_coles.dart and
      poisson_params.dart have an empty diff.
- [ ] **2 — the internet**: tipsters and forum posts, possession 5.
      Acceptance numbers legitimately move here.
- [ ] **3 — friends**: proposals, accept/reject/counter, gate 4, possession 6
- [ ] **4 — life sim**: needs, hours, job, rent, items, possession 7

## Deferred, deliberately

Two changes belong together in one re-baselining commit, because each moves
the acceptance numbers and doing them separately makes the movement
unattributable:

- `poisson_params.scoringRates` multiplies the home rate by `refereeBias`,
  which contradicts "referee bias reaches fouls and cards only".
- `LatentShocks.rollInjury` / `recoverInjuries` are still called from nowhere,
  so `injuredCount` never changes during a season.

Both alter the sampled score. Land them together, rerun
`scripts/check_acceptance.sh 200 9000`, and re-baseline the numbers in
`DOCS-acceptance-gate.md` as a deliberate, visible edit.

Full plan: `~/.claude/plans/sport-betting-simultoar-delegated-nova.md`
