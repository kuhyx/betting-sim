/// Which sub-seed a narration draw comes from.
///
/// One slot per (stat, side), which looks extravagant and is not. Sub-seeds
/// are hash-derived and O(1), so a slot costs nothing at runtime -- and
/// sharing a stream between two stats would mean that changing a hidden
/// factor shifted the draws of every stat after it. That would make
/// one-stat-one-factor a hope rather than a property: no test could assert it
/// by equality, only by tolerance, and a smuggled dependency would hide
/// inside the noise.
///
/// With a slot each, "morale does not touch corners" is an exact assertion.
///
/// Slots 0-3 belong to the existing engine (pre-match, match, book, bettor)
/// and are frozen. These take 4-17; 20 and up are reserved for the media,
/// social and life layers. Never renumber: a shifted slot changes every
/// draw under it, which voids saved games and frozen test literals.
enum NarrationSlot {
  /// The home side's attempts.
  homeShots(4),

  /// The away side's attempts.
  awayShots(5),

  /// Which of the home side's attempts were on target.
  homeOnTarget(6),

  /// Which of the away side's attempts were on target.
  awayOnTarget(7),

  /// The home side's corners.
  homeCorners(8),

  /// The away side's corners.
  awayCorners(9),

  /// The split of the ball. One draw, shared, because the two shares sum
  /// to 100 and cannot be drawn independently.
  possessionSplit(10),

  /// The home side's fouls and cards.
  homeDiscipline(11),

  /// The away side's fouls and cards.
  awayDiscipline(12),

  /// Who the home side's cards went to, and when.
  homeCardees(13),

  /// Who the away side's cards went to, and when.
  awayCardees(14),

  /// Who scored.
  scorers(15),

  /// Whether the home side lost someone, and who.
  homeInjury(16),

  /// Whether the away side lost someone, and who.
  awayInjury(17);

  /// Binds this slot to its `possession` index in the seed tree.
  const NarrationSlot(this.possession);

  /// The `SeedPath.possession` value this slot draws from.
  final int possession;
}
