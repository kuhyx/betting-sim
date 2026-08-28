/// Weather on a matchday. Heavy conditions suppress scoring for both sides.
enum Weather {
  /// Dry and still: no effect.
  clear,

  /// Wet: slightly fewer goals.
  rain,

  /// Wind or snow: markedly fewer goals, and more variance.
  storm,
}

/// Hidden per-club state that perturbs how a club performs.
///
/// NONE of this is ever shown to the player. It leaks only through noisy box
/// scores and news, and each field is deliberately given a DISTINCT
/// statistical fingerprint so a diligent player can regress it out:
///
///  * [fatigue] -> late-match scoring decay
///  * [morale]  -> higher variance rather than a shifted mean
///  * [form]    -> short-run autocorrelation in results
///
/// That separation is what makes the game learnable instead of a slot machine.
class LatentState {
  /// Creates a latent state.
  const LatentState({
    this.fatigue = 0,
    this.morale = 0,
    this.form = 0,
    this.injuredCount = 0,
  });

  /// Accumulated tiredness, 0 (fresh) to 1 (exhausted).
  final double fatigue;

  /// Confidence, -1 (dismal) to 1 (flying).
  final double morale;

  /// Short-run form, -1 (cold) to 1 (hot).
  final double form;

  /// How many first-choice players are currently unavailable.
  final int injuredCount;

  /// Returns a copy with the given fields replaced.
  LatentState copyWith({
    double? fatigue,
    double? morale,
    double? form,
    int? injuredCount,
  }) {
    return LatentState(
      fatigue: fatigue ?? this.fatigue,
      morale: morale ?? this.morale,
      form: form ?? this.form,
      injuredCount: injuredCount ?? this.injuredCount,
    );
  }

  @override
  String toString() {
    final f = fatigue.toStringAsFixed(2);
    final m = morale.toStringAsFixed(2);
    return 'LatentState(fatigue $f, morale $m, injured $injuredCount)';
  }
}

/// How a club's hidden state translates into match effects.
///
/// The scoreline model consumes only this, never [LatentState] itself, so the
/// latent values cannot leak into scoring by accident.
class MatchModifiers {
  /// Creates modifiers.
  const MatchModifiers({
    this.attackMultiplier = 1,
    this.defenceMultiplier = 1,
    this.varianceMultiplier = 1,
    this.lateMatchDecay = 0,
  });

  /// Scales the club's scoring rate.
  final double attackMultiplier;

  /// Scales the club's ability to suppress the opponent's scoring rate.
  final double defenceMultiplier;

  /// Widens or narrows the spread of outcomes without moving the mean.
  ///
  /// This is morale's fingerprint: a club with terrible morale is not simply
  /// worse, it is less predictable.
  final double varianceMultiplier;

  /// How much the club fades in the closing stages, 0..1.
  ///
  /// Fatigue's fingerprint. Visible only in when goals are scored, never in
  /// the final score alone -- so reading it requires match detail.
  final double lateMatchDecay;

  @override
  String toString() =>
      'MatchModifiers(atk '
      '${attackMultiplier.toStringAsFixed(3)}, '
      'var ${varianceMultiplier.toStringAsFixed(3)})';
}
