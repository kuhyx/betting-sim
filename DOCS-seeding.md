# Seeding and the random number generator

## Why the engine owns its generator

`dart:math`'s `Random(seed)` does not document its sequence as a stable
contract. That would be a footnote in most programs, but saves here are **a
seed plus event deltas** rather than full snapshots — the save file is a
promise that a given seed replays to a given season. An SDK upgrade could
silently void every existing save, a failure a test can detect but cannot
repair. Owning the generator makes the promise structural.

## Why it is 32-bit

The app ships to **Android** (native, 64-bit ints) and to a **Chrome-wrapped
web build** (JavaScript numbers: IEEE doubles, exact only to 53 bits).

A 64-bit generator does not merely lose precision on the web. `dart compile js`
**refuses to compile it**:

```
Error: The integer literal 0x9E3779B97F4A7C15 can't be represented exactly
       in JavaScript.
Error: The operator '>>>' isn't defined for the type 'num'.
```

This was found by trying it, not by reading about it. An initial SplitMix64
implementation passed its published reference vectors on the VM and was
unusable on the web target the plan had already chosen.

So every value stays inside 32 bits, and `mul32` splits its operand into 16-bit
halves so the largest intermediate product is 2^16 × 2^32 = 2^48 — comfortably
inside the 53 bits a double represents exactly.

**`scripts/check_rng_parity.sh` asserts this permanently**, compiling the
engine's generator to JavaScript and diffing its output against the VM. If the
two ever disagree by one bit, a game synced from the phone replays differently
on the desktop — silently, and only for some matches.

## Hash-derived, not stream-derived

`deriveSeed(SeedPath)` mixes a path — master → season → day → match →
possession — into a seed. Sub-seeds are **O(1) addressable**: reaching match
`(s, d, m)` never requires simulating the seasons or days before it.

That rules out stream-spawning RNG APIs, where reaching a position means
walking the tree. Addressability is what lets one match be replayed without
recomputing the universe, and it is what keeps saves small.

Each level is folded in under its own **domain tag**, so `(season 1, day 23)`
cannot collide with `(season 12, day 3)`, and `season 5` differs from `day 5`.
A test sweeps 8,000 paths and asserts no collisions.

## Rendering seeds in tests

Frozen-literal tests compare **bit patterns**. Dart ints are signed, and
`toUnsigned(64)` is a no-op at that width, so a negative value renders with a
leading `-` and does not show its bits. Use `hex32`. (The 64-bit prototype's
first reference value printed as `-1ddf57c684e23251` rather than
`e220a8397b1dcdaf` for exactly this reason.)

## The slot map

`possession` is the leaf level, and it is **append-only**. Renumbering a slot
changes every draw beneath it, which voids saved games and the frozen literals
below.

| slot | owner |
| ---- | ----- |
| 0 | pre-match: weather, referee bias |
| 1 | the match itself |
| 2 | the bookmaker |
| 3 | the bettor |
| 4-17 | the match narrator (`NarrationSlot`) |
| 20 | the panel of tipsters a save is stuck with |
| 21 | what they say about one fixture |
| 30-39 | reserved: friends |
| 40-49 | reserved: the life sim |

The narrator takes fourteen of them -- one per stat per side -- rather than
one. That is not extravagance: sub-seeds are hashes of a path, so a slot is
free, and sharing a stream between two stats would mean that changing a hidden
factor shifted the draws of every stat after it. One-stat-one-factor would then
only be assertable to a tolerance, and a smuggled dependency could hide in the
noise. With a slot each, "morale does not touch corners" is an assertion of
**equality**.

The rule that follows: **a new stat family takes a new slot.** Draw order
*inside* a slot may only be appended to.

## What is frozen

- `mix32Next`'s sequence from seed 0 (`test/rng/mix32_test.dart`).
- `deriveSeed`'s output for a table of paths (`test/rng/seeds_test.dart`).

Changing either invalidates every existing save. That must be a deliberate,
visible edit to these literals — never silent drift.
