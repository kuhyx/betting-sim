import 'package:league_engine/src/latent/config.dart';
import 'package:league_engine/src/latent/state.dart';

/// Projects hidden state into the effects the scoreline model consumes.
///
/// This is the ONLY route from [LatentState] into a match. The scoreline model
/// never sees the latent values themselves, so they cannot leak into scoring
/// by accident -- and each one is deliberately given a different observable
/// signature so the player can, in principle, tell them apart:
///
///  * fatigue -> lower scoring AND late-match decay (visible in goal timings)
///  * morale  -> variance only, mean unchanged (visible in result spread)
///  * form    -> a small mean shift that decays (visible as streakiness)
///  * injuries-> a step change in scoring (visible against team news)
///
/// The last three fields it fills ([MatchModifiers.formShift],
/// [MatchModifiers.moraleSpread], [MatchModifiers.missingCount]) exist for the
/// narrator rather than the scoreline: see [MatchModifiers].
class LatentModifiers {
  /// Creates a projection.
  const LatentModifiers([this.config = const LatentConfig()]);

  /// Rates and thresholds.
  final LatentConfig config;

  /// Projects [state] under [weather] into match effects.
  MatchModifiers project(LatentState state, {Weather weather = Weather.clear}) {
    // Fatigue and injuries cut scoring; form lifts it. Morale deliberately
    // does NOT appear here -- it acts on variance alone.
    final fatiguePenalty = 1 - config.fatigueAttackPenalty * state.fatigue;
    final injuryPenalty = 1 - config.injuryAttackPenalty * state.injuredCount;
    final formBonus = 1 + config.formAttackBonus * state.form;

    final weatherScoring = switch (weather) {
      Weather.clear => 1.0,
      Weather.rain => config.rainScoringMultiplier,
      Weather.storm => config.stormScoringMultiplier,
    };
    final weatherVariance = switch (weather) {
      Weather.clear => 1.0,
      Weather.rain => 1.0,
      Weather.storm => config.stormVarianceMultiplier,
    };

    // Low morale widens the spread, high morale narrows it: a confident side
    // performs to its level, a fragile one is unpredictable in both
    // directions.
    final moraleVariance = 1 - config.moraleVarianceSpread * state.morale;

    return MatchModifiers(
      attackMultiplier: _atLeastZero(
        fatiguePenalty * injuryPenalty * formBonus * weatherScoring,
      ),
      defenceMultiplier: _atLeastZero(fatiguePenalty * injuryPenalty),
      varianceMultiplier: _atLeastZero(moraleVariance * weatherVariance),
      lateMatchDecay: state.fatigue.clamp(0.0, 1.0),
      // The narrator's three unblended channels. Same inputs as above, kept
      // separable so each observable stat can be driven by exactly one of
      // them. Nothing on the scoreline path reads these.
      formShift: config.formAttackBonus * state.form,
      moraleSpread: config.moraleVarianceSpread * state.morale,
      missingCount: state.injuredCount,
    );
  }

  static double _atLeastZero(double v) => v < 0 ? 0 : v;
}
