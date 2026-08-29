/// Every rate and threshold the match narrator uses.
///
/// One frozen object, mirroring `LatentConfig`, for two reasons. It keeps the
/// generators free of magic numbers, and -- more usefully -- it is how the
/// tests reach rare branches WITHOUT searching for a lucky seed: setting
/// [redPerFoul] to 1 sends every foul off, and setting [foulsBase] to 0 takes
/// the empty-loop path. Config-forcing beats seed-hunting.
class NarrationConfig {
  /// Creates a config. Every default is a plausible league average.
  const NarrationConfig({
    this.shotsBase = 10,
    this.shotsPerStrength = 0.08,
    this.maxShots = 40,
    this.fatigueShotDecay = 0.45,
    this.onTargetBase = 0.36,
    this.formOnTarget = 1.5,
    this.onTargetFloor = 0.05,
    this.onTargetCeiling = 0.95,
    this.cornersBase = 4.8,
    this.cornersPerStrength = 0.05,
    this.possessionSigma = 6,
    this.possessionPerStrength = 0.25,
    this.moralePossessionSpread = 1.4,
    this.possessionFloor = 5,
    this.possessionCeiling = 95,
    this.foulsBase = 11,
    this.maxFouls = 40,
    this.yellowPerFoul = 0.13,
    this.redPerFoul = 0.006,
    this.injuryRatePerMatch = 0.08,
    this.staminaCeiling = 105,
    this.lineupSize = 11,
  });

  /// Shots an average side takes against an average one.
  final double shotsBase;

  /// Extra shots per point of attack-minus-opposing-defence.
  final double shotsPerStrength;

  /// Hard ceiling on a side's shot rate, so a freak strength gap cannot
  /// hand Knuth's Poisson method a rate it is slow at.
  final double maxShots;

  /// How much of the second half's shot rate a fully spent side loses.
  ///
  /// FATIGUE'S FINGERPRINT, and the only place it appears in the narrator.
  final double fatigueShotDecay;

  /// The share of non-scoring shots that are on target, at neutral form.
  final double onTargetBase;

  /// How strongly form moves that share.
  ///
  /// FORM'S FINGERPRINT. Read as conversion: goals over shots on target.
  final double formOnTarget;

  /// Lowest on-target share, however cold the side is.
  final double onTargetFloor;

  /// Highest on-target share, however hot.
  final double onTargetCeiling;

  /// Corners an average side wins against an average one.
  final double cornersBase;

  /// Extra corners per point of attack-minus-opposing-defence.
  final double cornersPerStrength;

  /// Spread of the possession split at neutral morale, in percentage points.
  final double possessionSigma;

  /// Possession points per point of strength difference.
  final double possessionPerStrength;

  /// How much morale widens the possession spread.
  ///
  /// MORALE'S FINGERPRINT. It scales a MEAN-ZERO term, so the expected split
  /// cannot move -- a fragile side is unpredictable, not worse.
  final double moralePossessionSpread;

  /// Lowest possession share a side can be shown as having.
  final double possessionFloor;

  /// Highest possession share a side can be shown as having.
  final double possessionCeiling;

  /// Fouls an average side concedes under an average referee.
  final double foulsBase;

  /// Hard ceiling on a side's foul rate, for the same reason as [maxShots].
  final double maxFouls;

  /// Chance a foul is booked.
  ///
  /// REFEREE BIAS'S FINGERPRINT, together with [foulsBase] and [redPerFoul].
  /// Cards never reach the scoreline: the narrator runs after it is sampled.
  final double yellowPerFoul;

  /// Chance a foul is a dismissal.
  final double redPerFoul;

  /// Chance a side picks up an injury during a match.
  final double injuryRatePerMatch;

  /// Just above the highest stamina a player has, so that
  /// `staminaCeiling - stamina` is a positive injury weight with no
  /// divide-by-zero and no clamping branch.
  final double staminaCeiling;

  /// How many players start a match.
  final int lineupSize;
}
