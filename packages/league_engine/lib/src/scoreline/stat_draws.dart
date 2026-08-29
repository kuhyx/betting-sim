import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/narration_config.dart';

/// A side's attempts, split either side of the interval.
typedef ShotSplit = ({int total, int firstHalf, int secondHalf});

/// A side's card record for a match.
typedef DisciplineDraw = ({int fouls, int yellows, int reds});

/// Draws a side's attempts, given how tired it is.
///
/// FATIGUE ONLY. The rate comes from PUBLIC strength -- attack minus the
/// opponent's defence -- never from `ScoringRates`, which has every latent
/// factor already blended into it and would smuggle all four in at once.
///
/// [goals] are added rather than drawn: every goal was a shot, so this is
/// `shots >= goals` by construction, with no `max` and no branch to cover.
///
/// [secondHalfGoals] is not bookkeeping. Filing every goal under the first
/// half would depress the second-half share of any side that scored late --
/// and how much a side scores carries all four latent factors blended
/// together, so it would leak every one of them into fatigue's fingerprint.
/// Goals land in the half they were actually scored in, which also sharpens
/// the signal: the scoreline model already pulls a tired side's goals
/// earlier.
///
/// Draw order is fixed and documented because scripted tests size their
/// queues from it: first half, then second half.
ShotSplit drawShots({
  required double strengthEdge,
  required double lateMatchDecay,
  required int goals,
  required int secondHalfGoals,
  required NarrationConfig config,
  required RandomSource rng,
}) {
  final rate = (config.shotsBase + config.shotsPerStrength * strengthEdge)
      .clamp(0.0, config.maxShots);
  final first = rng.poisson(rate / 2);
  // A spent side stops creating chances after the hour. This is the only
  // place fatigue enters the narrator, and it is invisible in the final
  // score -- which is exactly why watching a match is worth the time.
  final second = rng.poisson(
    rate / 2 * (1 - config.fatigueShotDecay * lateMatchDecay),
  );
  return (
    total: goals + first + second,
    firstHalf: first + goals - secondHalfGoals,
    secondHalf: second + secondHalfGoals,
  );
}

/// Draws how many attempts were on target, given the side's form.
///
/// FORM ONLY. Every goal was on target, so those are added; the rest are
/// Bernoulli trials at a form-shifted rate, one uniform each. The readable
/// number is conversion -- goals over shots on target -- which rises when a
/// side is hot and falls when it is not.
int drawShotsOnTarget({
  required int nonScoringShots,
  required int goals,
  required double formShift,
  required NarrationConfig config,
  required RandomSource rng,
}) {
  final p = (config.onTargetBase + config.formOnTarget * formShift).clamp(
    config.onTargetFloor,
    config.onTargetCeiling,
  );
  var onTarget = goals;
  for (var i = 0; i < nonScoringShots; i++) {
    if (rng.uniform01() < p) {
      onTarget++;
    }
  }
  return onTarget;
}

/// Draws corners won.
///
/// NO LATENT FACTOR AT ALL, deliberately. Corners add texture to a match
/// report without adding a fifth thing to regress out; a stat that moved with
/// a hidden factor nobody could isolate would make the others harder to read,
/// not easier.
int drawCorners({
  required double strengthEdge,
  required NarrationConfig config,
  required RandomSource rng,
}) {
  return rng.poisson(
    (config.cornersBase + config.cornersPerStrength * strengthEdge).clamp(
      0.0,
      config.maxShots,
    ),
  );
}

/// Draws the home side's share of the ball.
///
/// MORALE ONLY, and it enters as a SCALE ON A MEAN-ZERO TERM, so the expected
/// split cannot move however fragile either side is. That is morale's whole
/// fingerprint: wider spread, mean unchanged. A test pins it exactly by
/// feeding a normal deviate of zero and asserting the two morale extremes
/// produce the same number.
///
/// [moraleSpread] is the two sides' morale terms combined; low morale widens,
/// matching `LatentModifiers`, where low morale raises the variance
/// multiplier. The scale stays positive across the whole legal range, and a
/// negative one would merely mirror a symmetric distribution anyway.
double drawHomePossession({
  required double strengthEdge,
  required double moraleSpread,
  required NarrationConfig config,
  required RandomSource rng,
}) {
  final tilt = 50 + config.possessionPerStrength * strengthEdge;
  final scale = 1 - config.moralePossessionSpread * moraleSpread;
  final drawn = tilt + rng.normal(0, config.possessionSigma * scale);
  return drawn.clamp(config.possessionFloor, config.possessionCeiling);
}

/// Draws fouls and the cards that came of them.
///
/// REFEREE BIAS ONLY, and it reaches nothing else. Because the narrator runs
/// AFTER the scoreline is sampled, a dismissal structurally cannot change the
/// score -- so a side will occasionally go down to ten men and still win 3-0.
/// That artifact is the price of one-stat-one-factor. Do not "fix" it by
/// feeding cards back into scoring: that would leak referee bias into goals
/// and break the model's agreement with its own prices.
///
/// One uniform per foul, tested against red first so that a config with
/// `redPerFoul: 1` sends everyone off and the rare branch needs no lucky seed.
DisciplineDraw drawDiscipline({
  required double refereeBias,
  required NarrationConfig config,
  required RandomSource rng,
}) {
  final fouls = rng.poisson(
    (config.foulsBase * refereeBias).clamp(0.0, config.maxFouls),
  );
  final redAt = config.redPerFoul * refereeBias;
  final yellowAt = redAt + config.yellowPerFoul * refereeBias;

  var yellows = 0;
  var reds = 0;
  for (var i = 0; i < fouls; i++) {
    final roll = rng.uniform01();
    if (roll < redAt) {
      reds++;
    } else if (roll < yellowAt) {
      yellows++;
    }
  }
  return (fouls: fouls, yellows: yellows, reds: reds);
}

/// Whether a side picked up an injury during play. Exactly one draw, always.
bool drawInjury({
  required NarrationConfig config,
  required RandomSource rng,
}) {
  return rng.uniform01() < config.injuryRatePerMatch;
}
