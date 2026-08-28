# The acceptance gate

The engine is worthless if it is not **learnable**. A betting game whose
outcomes are RNG behind cosmetic odds is a slot machine: there is nothing to
get good at, so there is no content. These four numbers decide whether that is
true, and nothing downstream is built while they fail.

```sh
scripts/check_acceptance.sh 200 9000
```

## What each gate asserts

**Gate 1 — skill pays over a season.** The skilled bettor's mean per-season ROI
is positive and its 95% confidence interval excludes zero.

Asserted on the **mean of per-season ROIs**, never on pooled profit over pooled
stake. Kelly staking compounds, so a winning season stakes several times what a
losing one does and pooling silently overweights the good ones — measured at
+0.79% pooled against a −2.1% median season.

**Gate 2 — one night is a coin flip.** Between 45% and 55% of the matchdays on
which a bet was struck lose money.

This is about **variance, not expectation**. Expectation is linear in bets: if
every bet is +EV then every subset is too, so a strategy cannot be +EV over a
season and −EV over one night. The asymmetry is that one night's noise hides
the edge completely.

Only matchdays with at least one bet count. A disciplined strategy sits out
many nights, and scoring those as ROI 0 would swamp the median and turn the
losing-night fraction into a measure of bet frequency.

The **losing fraction** is the assertion, not the median. The median matchday
ROI is by design a statistic that sits at zero, so testing its sign measures
sampling noise — across 40/80/150/200 seasons it read +0.64%, +0.30%, −0.87%,
−1.35% while the fraction held at 49.7%, 49.9%, 50.5%, 50.6%.

**Gate 3a — the book charges exactly its margin.** Against a deliberately
infallible book, a random bettor's ROI is `−v/(1+v)`.

Under a proportional margin `price_i = 1/(p_i·(1+v))`, so the expected return on
*any* selection is `p_i · price_i = 1/(1+v)`, independent of the probabilities
and of which outcome is picked. Anything else means the pricing arithmetic is
wrong and every other number here is untrustworthy.

**Gate 3b — chance loses, and skill beats chance.** In the live market, the
random bettor loses money and the skilled bettor does better.

Stated separately from 3a because a fallible book **necessarily** leaks value
to every bettor, random ones included: its pricing errors do not cancel in
payout terms. The live market returns a random bettor about −3.1% against the
−4.76% a perfect book charges, and that 1.7pp gap *is* the book's fallibility —
the same fallibility that makes a studious player's edge possible at all.
Demanding the exact identity here would demand an infallible book, and an
infallible book makes the game unwinnable by construction.

## The oracle is a control, not a subject

`OracleBettor` reads the true probabilities and so cheats by construction. It
is reported to answer **"is gate 1 reachable at all"** before anyone asks
whether a given strategy reaches it. If perfect knowledge cannot clear the
margin, the game is unwinnable and no tuning of the skilled bettor would help.

It currently returns about +20% ROI with a 97.6% beat rate, so there is real
headroom above the +1.5% the skilled bettor earns.

Worth knowing: against a book that prices the truth *exactly*, even the oracle
declines every bet. Perfect knowledge is not an edge — an edge requires the
book to be **wrong**. That is why the skilled bettor is built around an
information gap rather than around better arithmetic.

## Where the edge comes from

The skilled bettor never reads the true probabilities. It takes the book's own
published opinion, de-vigged, and corrects it for the one thing the book prices
badly: how tired and how in-form the two clubs are. Fixture lists and results
are public, so this is information a diligent player could genuinely gather.

`SeasonRunner.bookLatentAwareness` is the knob that decides how much of that
state the book already prices, and it is the balance point of the whole game:

| awareness | random | skilled | oracle |
| --------- | ------ | ------- | ------ |
| 1.00 | −4.12% | −4.54% | +22.80% |
| 0.90 | −4.17% | −2.15% | +22.70% |
| 0.80 | −4.16% | +0.44% | +22.78% |
| 0.70 | −4.07% | +3.21% | +23.03% |
| 0.50 | −3.69% | +9.47% | +24.86% |

At 1.0 there is nothing to know. At 0.0 the market is so soft that a *random*
bettor profits, which means the house edge has stopped existing. 0.7 is the
shipped value. Note the random column barely moves: that is the check that the
house edge survives whatever this is tuned to.

## Running it

CI runs the gate at 150 seasons, about 11 seconds. At 40 seasons it correctly
**fails** gate 1 — the confidence interval is too wide to claim an edge, which
is the gate refusing to assert what the data does not support.
