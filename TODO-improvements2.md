# Part 2 — what is left

REMOVE ME AFTER FINISH

The four things the game was missing are built and shipped:

- [x] **0 — shell**: navigation, calendar, local save
- [x] **1 — the match happens**: timeline, stats, players, slots 4-17
- [x] **2 — the internet**: tipsters and forum posts, slots 20-21, gate 4
- [x] **3 — friends**: take/leave/haggle, gate 5, slots 30-31
- [x] **4 — life sim**: hours, needs, wages, rent, eviction, gate 6

## What is deliberately still open

Two changes belong together in ONE re-baselining commit, because each moves the
acceptance numbers and doing them separately makes the movement unattributable:

1. `poisson_params.scoringRates` multiplies the home scoring rate by
   `ctx.refereeBias`. That contradicts the fingerprint table in
   `DOCS-architecture.md`, which says referee bias reaches fouls and cards and
   nothing else. Removing it changes `outcomeProbabilities` AND `simulate`
   together.
2. `LatentShocks.rollInjury` / `recoverInjuries` are still called from nowhere,
   so `injuredCount` never changes during a season. Wiring them changes
   `injuredCount` -> `injuryPenalty` -> `attackMultiplier` -> the sampled score.

Land them together, rerun `scripts/check_acceptance.sh 200 9000`, and
re-baseline the numbers in `DOCS-acceptance-gate.md` as a deliberate, visible
edit. Only after that can "referee bias does not change the scoreline" be
written as a test.

## Smaller things noticed along the way

- The `study` and `watch` hours cost time but do not yet BUY anything: reading
  the feed is free once you are on the tab. Gating the feed behind hours spent
  is the obvious next turn of the screw, and the reason `Activity.study`
  already exists.
- `LimitPolicy` in `book/limits.dart` is still unwired: only the static
  per-market `Market.limit` is enforced. A player who beats the closing line
  repeatedly should get restricted, and the policy for it is already written.
