import 'package:betting_sim/state/settler.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// One line of a match report.
class MatchEventRow extends StatelessWidget {
  /// Creates a row for [event] in [match].
  const MatchEventRow({required this.event, required this.match, super.key});

  /// What happened.
  final MatchEvent event;

  /// The match it happened in, for looking names up.
  final PlayedMatch match;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (label, colour, home) = _describe();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space4,
        vertical: Tokens.space2,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Text(
              "${event.minute}'",
              style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
            ),
          ),
          Container(width: 3, height: 18, color: colour),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(
                fontWeight: home ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            home ? match.home.name : match.away.name,
            style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
          ),
        ],
      ),
    );
  }

  (String, Color, bool) _describe() {
    return switch (event) {
      final GoalEvent e => (
        'GOAL — ${_name(e.playerId, home: e.byHome)}',
        Tokens.success,
        e.byHome,
      ),
      final YellowCardEvent e => (
        'booked — ${_name(e.playerId, home: e.homeSide)}',
        Tokens.warning,
        e.homeSide,
      ),
      final RedCardEvent e => (
        'SENT OFF — ${_name(e.playerId, home: e.homeSide)}',
        Tokens.danger,
        e.homeSide,
      ),
      final InjuryEvent e => (
        'injured — ${_name(e.playerId, home: e.homeSide)}',
        Tokens.mutedOnDark,
        e.homeSide,
      ),
    };
  }

  /// Resolves a player id to a name.
  ///
  /// Falls back rather than throwing: `GoalEvent.playerId` is nullable, and a
  /// club whose whole squad is unavailable really can score without anyone to
  /// credit it to.
  String _name(int? id, {required bool home}) {
    final squad = home ? match.home.players : match.away.players;
    for (final player in squad) {
      if (player.id == id) {
        return player.name;
      }
    }
    return 'unknown';
  }
}
