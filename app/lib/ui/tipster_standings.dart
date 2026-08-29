import 'package:betting_sim/state/ledger.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// Your notebook on the panel: who has actually been worth following.
///
/// The game never marks anybody as sharp. Confidence is drawn independently
/// of skill, so the feed cannot be read at a glance -- the only way to find
/// the two people worth listening to is to write down what they said and
/// check later. This is that notebook, kept for you.
class TipsterStandings extends StatelessWidget {
  /// Creates the table.
  const TipsterStandings({
    required this.ledger,
    required this.tipsters,
    super.key,
  });

  /// What has settled so far.
  final TipsterLedger ledger;

  /// Who is on the panel, for their handles.
  final List<Tipster> tipsters;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rows = ledger.standings;
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space5),
          child: Text(
            'play a matchday and their calls start settling here.\n'
            'nothing in the game will tell you who is any good.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(Tokens.space4),
      itemCount: rows.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space3),
            child: Text(
              'what a flat 10 on every call would have done',
              style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
            ),
          );
        }
        final row = rows[i - 1];
        return _StandingRow(
          handle: tipsters[row.tipsterId].handle,
          record: row.record,
        );
      },
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.handle, required this.record});

  final String handle;
  final TipsterRecord record;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final roi = record.roi;
    final colour = roi == null || roi == 0
        ? Tokens.mutedOnDark
        : (roi > 0 ? Tokens.success : Tokens.danger);
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.space2),
      padding: const EdgeInsets.all(Tokens.space3),
      color: Tokens.inkRaised1,
      child: Row(
        children: <Widget>[
          Expanded(child: Text(handle, style: text.bodyMedium)),
          Text(
            '${record.hits}/${record.tips}',
            style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
          ),
          const SizedBox(width: Tokens.space4),
          SizedBox(
            width: 72,
            child: Text(
              roi == null ? '--' : '${(roi * 100).toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: text.bodyMedium?.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}
