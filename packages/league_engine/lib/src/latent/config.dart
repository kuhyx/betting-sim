/// Every rate and threshold the latent layer uses.
///
/// Grouped into one frozen object rather than passed as loose scalars: it
/// keeps call sites within the argument-count lint, and -- more importantly --
/// it is the primary way tests reach rare branches. Setting
/// `injuryBaseRate: 1` forces an injury through the real code path, with no
/// stubbing and no seed search.
class LatentConfig {
  /// Creates a config.
  const LatentConfig({
    this.fatiguePerMatch = 0.18,
    this.fatigueRecoveryPerDay = 0.12,
    this.injuryBaseRate = 0.04,
    this.injuryFatigueScaling = 0.06,
    this.injuryRecoveryDays = 21,
    this.moraleWinDelta = 0.22,
    this.moraleLossDelta = -0.26,
    this.moraleDrawDelta = -0.02,
    this.moraleDecay = 0.9,
    this.formDecay = 0.75,
    this.formWinDelta = 0.3,
    this.formLossDelta = -0.3,
    this.fatigueAttackPenalty = 0.22,
    this.moraleVarianceSpread = 0.35,
    this.injuryAttackPenalty = 0.035,
    this.formAttackBonus = 0.08,
    this.rainScoringMultiplier = 0.92,
    this.stormScoringMultiplier = 0.8,
    this.stormVarianceMultiplier = 1.15,
    this.rainProbability = 0.22,
    this.stormProbability = 0.07,
    this.refereeBiasSpread = 0.05,
  });

  /// Fatigue added by playing a match.
  final double fatiguePerMatch;

  /// Fatigue shed per day of rest.
  final double fatigueRecoveryPerDay;

  /// Baseline chance per match that a club picks up an injury.
  final double injuryBaseRate;

  /// How much fatigue raises the injury rate.
  final double injuryFatigueScaling;

  /// How long an injury keeps a player out.
  final int injuryRecoveryDays;

  /// Morale gained by a win.
  final double moraleWinDelta;

  /// Morale lost by a defeat. Larger in magnitude than a win's gain: losing
  /// hurts more than winning helps, which is what makes slumps self-sustaining.
  final double moraleLossDelta;

  /// Morale change on a draw.
  final double moraleDrawDelta;

  /// How much morale persists between matches.
  final double moraleDecay;

  /// How much form persists between matches.
  final double formDecay;

  /// Form gained by a win.
  final double formWinDelta;

  /// Form lost by a defeat.
  final double formLossDelta;

  /// How much full fatigue cuts scoring.
  final double fatigueAttackPenalty;

  /// How much morale widens or narrows outcome spread.
  final double moraleVarianceSpread;

  /// Scoring lost per injured player.
  final double injuryAttackPenalty;

  /// Scoring gained at full form.
  final double formAttackBonus;

  /// Scoring multiplier in rain.
  final double rainScoringMultiplier;

  /// Scoring multiplier in a storm.
  final double stormScoringMultiplier;

  /// Variance multiplier in a storm: bad conditions level the sides.
  final double stormVarianceMultiplier;

  /// Chance of rain on a given matchday.
  final double rainProbability;

  /// Chance of a storm on a given matchday.
  final double stormProbability;

  /// Spread of the per-match referee bias, as a fraction of scoring rate.
  final double refereeBiasSpread;
}
