/// One side's box score for a match.
///
/// The observable half of the game. Every field here is driven by exactly ONE
/// hidden factor, so a player who keeps records can regress them apart; if two
/// factors moved the same number the same way, no amount of study could
/// separate them and the stat would be decoration.
///
/// | field | driven by |
/// | ----- | --------- |
/// | [shots], [secondHalfShots] | fatigue |
/// | [shotsOnTarget] (as conversion) | form |
/// | [possessionPercent] (as spread) | morale |
/// | [fouls], [yellows], [reds] | referee bias |
/// | [corners] | public strength only |
class TeamMatchStats {
  /// Creates a box score.
  const TeamMatchStats({
    required this.goals,
    required this.shots,
    required this.secondHalfShots,
    required this.shotsOnTarget,
    required this.corners,
    required this.fouls,
    required this.yellows,
    required this.reds,
    required this.possessionPercent,
  });

  /// Goals scored. Comes from the scoreline model, never from the narrator.
  final int goals;

  /// Total attempts, including the ones that went in.
  final int shots;

  /// How many of [shots] came after the interval.
  ///
  /// Fatigue reads here and nowhere else: a spent side stops creating.
  final int secondHalfShots;

  /// Attempts that tested the goalkeeper or went in.
  final int shotsOnTarget;

  /// Corners won.
  final int corners;

  /// Fouls conceded.
  final int fouls;

  /// Yellow cards shown.
  final int yellows;

  /// Red cards shown.
  final int reds;

  /// Share of the ball, 0..100. The two sides sum to 100.
  final double possessionPercent;

  /// The share of attempts that came after the interval.
  ///
  /// Fatigue's readable number: at rest it sits near 0.5 and falls as a side
  /// tires. Null when nobody had a shot, because 0/0 is not "balanced".
  double? get secondHalfShotShare =>
      shots == 0 ? null : secondHalfShots / shots;

  /// Goals per shot on target.
  ///
  /// Form's readable number. Null when nothing was on target.
  double? get conversionRate =>
      shotsOnTarget == 0 ? null : goals / shotsOnTarget;

  @override
  String toString() =>
      'TeamMatchStats(g$goals s$shots($shotsOnTarget) '
      'c$corners f$fouls y$yellows r$reds '
      '${possessionPercent.toStringAsFixed(0)}%)';
}
