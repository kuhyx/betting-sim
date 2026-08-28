/// What happened in a match, as a stream of typed deltas.
///
/// These are both the box-score source AND the save-file format: a save is a
/// seed plus these events, never a full snapshot. That is what keeps saves
/// small enough to sync between the phone and the desktop.
sealed class MatchEvent {
  /// Creates an event at [minute].
  const MatchEvent(this.minute);

  /// The minute it happened, 1..90.
  final int minute;
}

/// A goal.
class GoalEvent extends MatchEvent {
  /// Creates a goal.
  const GoalEvent({
    required int minute,
    required this.byHome,
    required this.playerId,
  }) : super(minute);

  /// Whether the home side scored.
  final bool byHome;

  /// Who scored. Nullable in tests and for own goals.
  final int? playerId;

  @override
  String toString() => "Goal(${byHome ? 'H' : 'A'} $minute')";
}

/// A player picked up an injury during play.
class InjuryEvent extends MatchEvent {
  /// Creates an injury.
  const InjuryEvent({
    required int minute,
    required this.homeSide,
    required this.playerId,
  }) : super(minute);

  /// Whether the injured player belongs to the home side.
  final bool homeSide;

  /// Who was hurt.
  final int playerId;

  @override
  String toString() => "Injury(${homeSide ? 'H' : 'A'} $minute')";
}

/// A player was sent off.
class RedCardEvent extends MatchEvent {
  /// Creates a dismissal.
  const RedCardEvent({
    required int minute,
    required this.homeSide,
    required this.playerId,
  }) : super(minute);

  /// Whether the dismissed player belongs to the home side.
  final bool homeSide;

  /// Who was sent off.
  final int playerId;

  @override
  String toString() => "Red(${homeSide ? 'H' : 'A'} $minute')";
}
