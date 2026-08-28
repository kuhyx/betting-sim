import 'package:league_engine/src/latent/config.dart';
import 'package:league_engine/src/latent/state.dart';

/// The result of a match from one club's point of view.
enum MatchOutcome {
  /// A win.
  win,

  /// A draw.
  draw,

  /// A defeat.
  loss,
}

/// Deterministic day-to-day evolution of a club's hidden state.
///
/// Separated from [shocks.dart] on purpose: everything here is a pure function
/// of the previous state, so it can be reasoned about and tested without any
/// randomness at all.
class LatentDecay {
  /// Creates a decay model.
  const LatentDecay([this.config = const LatentConfig()]);

  /// Rates and thresholds.
  final LatentConfig config;

  /// Applies one day of rest.
  ///
  /// Fatigue falls; morale and form drift back toward neutral. A club left
  /// alone therefore returns to average, which is what stops early results
  /// from marking a club forever.
  LatentState rest(LatentState state, {int days = 1}) {
    var next = state;
    for (var d = 0; d < days; d++) {
      next = next.copyWith(
        fatigue: _clamp01(next.fatigue - config.fatigueRecoveryPerDay),
        morale: next.morale * config.moraleDecay,
        form: next.form * config.formDecay,
      );
    }
    return next;
  }

  /// Applies the effect of having played a match with [outcome].
  LatentState afterMatch(LatentState state, MatchOutcome outcome) {
    final moraleDelta = switch (outcome) {
      MatchOutcome.win => config.moraleWinDelta,
      MatchOutcome.draw => config.moraleDrawDelta,
      MatchOutcome.loss => config.moraleLossDelta,
    };
    final formDelta = switch (outcome) {
      MatchOutcome.win => config.formWinDelta,
      MatchOutcome.draw => 0.0,
      MatchOutcome.loss => config.formLossDelta,
    };

    return state.copyWith(
      fatigue: _clamp01(state.fatigue + config.fatiguePerMatch),
      morale: _clampSigned(state.morale + moraleDelta),
      form: _clampSigned(state.form + formDelta),
    );
  }

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
  static double _clampSigned(double v) => v < -1 ? -1 : (v > 1 ? 1 : v);
}
