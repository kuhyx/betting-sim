import 'package:league_engine/src/latent/config.dart';
import 'package:league_engine/src/latent/state.dart';
import 'package:league_engine/src/rng/source.dart';

/// The random events that disturb a club's hidden state.
///
/// Every method takes its [RandomSource] explicitly, so a test can script an
/// injury without also having to supply every unrelated draw.
class LatentShocks {
  /// Creates a shock model.
  const LatentShocks([this.config = const LatentConfig()]);

  /// Rates and thresholds.
  final LatentConfig config;

  /// Rolls for a new injury, given how tired the club is.
  ///
  /// Fatigue raises the rate, which is the mechanism connecting a congested
  /// fixture list to a thinner squad -- a chain the player can learn to
  /// anticipate from the schedule alone.
  bool rollInjury(LatentState state, RandomSource rng) {
    final rate =
        config.injuryBaseRate + config.injuryFatigueScaling * state.fatigue;
    return rng.uniform01() < rate;
  }

  /// Rolls the weather for a matchday.
  Weather rollWeather(RandomSource rng) {
    final roll = rng.uniform01();
    if (roll < config.stormProbability) {
      return Weather.storm;
    }
    if (roll < config.stormProbability + config.rainProbability) {
      return Weather.rain;
    }
    return Weather.clear;
  }

  /// Rolls a referee's bias for a match, as a multiplier on the home side's
  /// scoring rate.
  ///
  /// Centred on 1, so across a season it washes out -- it adds noise to a
  /// single match without making any club systematically luckier.
  double rollRefereeBias(RandomSource rng) =>
      1 + rng.normal(0, config.refereeBiasSpread);

  /// Advances injuries by one day, returning how many players are still out.
  int recoverInjuries(LatentState state, int daysSinceInjury) {
    if (state.injuredCount == 0) {
      return 0;
    }
    return daysSinceInjury >= config.injuryRecoveryDays
        ? state.injuredCount - 1
        : state.injuredCount;
  }
}
