import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// The box score, shown once the match has finished.
///
/// Deliberately NOT revealed minute by minute. The narrator produces match
/// TOTALS; showing a running count would mean inventing a distribution over
/// the ninety minutes that the engine never drew, and the whole point of the
/// timeline is that nothing on screen is fabricated.
class MatchStatsPanel extends StatelessWidget {
  /// Creates the panel.
  const MatchStatsPanel({
    required this.home,
    required this.away,
    required this.revealed,
    super.key,
  });

  /// The home side's box score.
  final TeamMatchStats home;

  /// The away side's box score.
  final TeamMatchStats away;

  /// Whether the match has reached full time.
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!revealed) {
      return Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Text(
          'full-time stats at 90′',
          style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
        ),
      );
    }

    return Container(
      color: Tokens.inkRaised1,
      padding: const EdgeInsets.all(Tokens.space4),
      child: Column(
        children: <Widget>[
          _row(context, 'shots', '${home.shots}', '${away.shots}'),
          _row(
            context,
            'after the break',
            '${home.secondHalfShots}',
            '${away.secondHalfShots}',
          ),
          _row(
            context,
            'on target',
            '${home.shotsOnTarget}',
            '${away.shotsOnTarget}',
          ),
          _row(context, 'corners', '${home.corners}', '${away.corners}'),
          _row(context, 'fouls', '${home.fouls}', '${away.fouls}'),
          _row(context, 'yellows', '${home.yellows}', '${away.yellows}'),
          _row(context, 'reds', '${home.reds}', '${away.reds}'),
          _row(
            context,
            'possession',
            '${home.possessionPercent.round()}%',
            '${away.possessionPercent.round()}%',
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String h, String a) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Text(h, style: text.bodyMedium, textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
            ),
          ),
          SizedBox(width: 44, child: Text(a, style: text.bodyMedium)),
        ],
      ),
    );
  }
}
