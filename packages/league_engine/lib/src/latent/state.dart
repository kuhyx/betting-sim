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
///
/// Two groups of fields, and the split is load-bearing:
///
///  * [attackMultiplier], [defenceMultiplier], [varianceMultiplier] and
///    [lateMatchDecay] feed the SCORELINE. They deliberately MIX the latent
///    factors together -- `attackMultiplier` alone carries fatigue, injuries,
///    form and weather, and no observer can take it apart.
///  * [formShift], [moraleSpread] and [missingCount] feed the NARRATOR, which
///    elaborates an already-sampled result into match detail. Each isolates
///    exactly one factor, because one-stat-one-factor is impossible if the
///    generator can only see the blend.
///
/// The scoreline must never read the second group. `dixon_coles.dart` and
/// `poisson_params.dart` are unchanged by the commit that added them, and
/// that empty diff is the proof.
class MatchModifiers {
  /// Creates modifiers.
  const MatchModifiers({
    this.attackMultiplier = 1,
    this.defenceMultiplier = 1,
    this.varianceMultiplier = 1,
    this.lateMatchDecay = 0,
    this.formShift = 0,
    this.moraleSpread = 0,
    this.missingCount = 0,
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

  /// Form on its own, roughly -0.1..0.1. Narrator input only.
  ///
  /// Drives shot CONVERSION and nothing else: a side in form puts the same
  /// number of chances away more often. Already inside [attackMultiplier] as
  /// part of the blend; repeated here so the narrator can see it alone.
  final double formShift;

  /// Morale on its own, roughly -0.35..0.35. Narrator input only.
  ///
  /// Drives the SPREAD of possession and nothing else, scaling a mean-zero
  /// term so the mean cannot move. That is morale's whole fingerprint: a
  /// fragile side is unpredictable, not worse.
  final double moraleSpread;

  /// How many first-choice players are unavailable. Narrator input only.
  ///
  /// Drives the team sheet, which is the one place injuries are directly
  /// READABLE rather than merely inferable from a step down in scoring.
  final int missingCount;

  @override
  String toString() =>
      'MatchModifiers(atk '
      '${attackMultiplier.toStringAsFixed(3)}, '
      'var ${varianceMultiplier.toStringAsFixed(3)})';
}
