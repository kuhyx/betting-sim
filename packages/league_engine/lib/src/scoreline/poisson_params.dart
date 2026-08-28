import 'dart:math' as math;

import 'package:league_engine/src/scoreline/protocol.dart';

/// Tunables for turning club strength into scoring rates.
class ScoringConfig {
  /// Creates a config.
  const ScoringConfig({
    this.baseRate = 1.15,
    this.homeAdvantage = 1.25,
    this.strengthScale = 0.006,
    this.lowScoreCorrection = -0.05,
    this.maxGoals = 12,
  });

  /// League-average goals per side per match, before any adjustment.
  ///
  /// Measured across a full 380-fixture season, 1.15 with the defaults below
  /// yields ~2.6 goals a game and a 43/27/30 home/draw/away split -- close to
  /// a real low-scoring league (~2.7 goals, ~46/27/27).
  final double baseRate;

  /// Multiplier on the home side's rate. Home advantage is real and large,
  /// and the player must learn to price it.
  final double homeAdvantage;

  /// How sharply squad strength translates into scoring rate.
  ///
  /// The other main balance knob beside LeagueConfig.abilitySpread: together
  /// they set how far talent separates from noise over a season. Measured at
  /// 0.006, home-win probability spans 0.25..0.63 across a season's fixtures:
  /// real signal to find, but no match is a foregone conclusion. Raising it to
  /// 0.02 pushed the extremes past 0.70 and made favourites too readable.
  final double strengthScale;

  /// Dixon-Coles tau: the dependence correction for low scores.
  ///
  /// Independent Poissons under-predict 0-0 and 1-1 and over-predict 1-0 and
  /// 0-1. Negative values shift mass toward the draws.
  final double lowScoreCorrection;

  /// Cap on the score grid used for exact probabilities.
  final int maxGoals;
}

/// The scoring rates for one match.
class ScoringRates {
  /// Creates a rate pair.
  const ScoringRates({required this.home, required this.away});

  /// The home side's expected goals.
  final double home;

  /// The away side's expected goals.
  final double away;

  @override
  String toString() =>
      'ScoringRates(${home.toStringAsFixed(3)}, '
      '${away.toStringAsFixed(3)})';
}

/// Computes both sides' scoring rates from strength, venue and hidden state.
ScoringRates scoringRates(MatchContext ctx, ScoringConfig config) {
  // Attack is measured against the opponent's defence, so a strong attack
  // facing a strong defence produces an ordinary game rather than a rout.
  final homeEdge =
      (ctx.home.attackStrength - ctx.away.defenceStrength) *
      config.strengthScale;
  final awayEdge =
      (ctx.away.attackStrength - ctx.home.defenceStrength) *
      config.strengthScale;

  final home =
      config.baseRate *
      math.exp(homeEdge) *
      config.homeAdvantage *
      ctx.homeModifiers.attackMultiplier *
      ctx.awayModifiers.defenceMultiplier *
      ctx.refereeBias;

  final away =
      config.baseRate *
      math.exp(awayEdge) *
      ctx.awayModifiers.attackMultiplier *
      ctx.homeModifiers.defenceMultiplier;

  // A rate of zero would make the match unplayable; clamp just above it.
  return ScoringRates(
    home: math.max(home, 0.01),
    away: math.max(away, 0.01),
  );
}

/// The Dixon-Coles tau correction for a specific low scoreline.
///
/// Applies only to 0-0, 0-1, 1-0 and 1-1, which is exactly where independent
/// Poissons are known to misprice; every other score is left untouched.
double dixonColesTau(
  int homeGoals,
  int awayGoals,
  double lambdaHome,
  double lambdaAway,
  double rho,
) {
  if (homeGoals == 0 && awayGoals == 0) {
    return 1 - lambdaHome * lambdaAway * rho;
  }
  if (homeGoals == 0 && awayGoals == 1) {
    return 1 + lambdaHome * rho;
  }
  if (homeGoals == 1 && awayGoals == 0) {
    return 1 + lambdaAway * rho;
  }
  if (homeGoals == 1 && awayGoals == 1) {
    return 1 - rho;
  }
  return 1;
}
