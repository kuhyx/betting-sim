import 'package:league_engine/src/scoreline/events.dart';
import 'package:league_engine/src/scoreline/lineup.dart';
import 'package:league_engine/src/scoreline/match_stats.dart';

/// A match as something you can watch, rather than a number that appeared.
///
/// Produced by the narrator from an ALREADY-SAMPLED `MatchResult`. Nothing
/// here can change the score: the timeline elaborates a result, it does not
/// decide one. That ordering is what lets the acceptance gate keep measuring
/// the same game while the match report gains detail.
class MatchTimeline {
  /// Creates a timeline.
  const MatchTimeline({
    required this.events,
    required this.home,
    required this.away,
    required this.homeSheet,
    required this.awaySheet,
  });

  /// Everything that happened, earliest first.
  final List<MatchEvent> events;

  /// The home side's box score.
  final TeamMatchStats home;

  /// The away side's box score.
  final TeamMatchStats away;

  /// Who played for the home side, and who was missing.
  final TeamSheet homeSheet;

  /// Who played for the away side, and who was missing.
  final TeamSheet awaySheet;

  /// The events that had happened by [minute], for following a match live.
  List<MatchEvent> upTo(int minute) =>
      events.where((e) => e.minute <= minute).toList();
}
