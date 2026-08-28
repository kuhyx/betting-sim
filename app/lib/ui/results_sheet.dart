import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';

/// What the matchday did to the player's money.
///
/// Shows every settled bet with its scoreline, because the result is the only
/// window onto the hidden state -- a run of unexpected scores is how a player
/// learns a club is tired, and hiding the detail would remove the game.
class ResultsSheet extends StatelessWidget {
  /// Creates a results sheet.
  const ResultsSheet({required this.bets, super.key});

  /// The bets settled this matchday.
  final List<PlayerBet> bets;

  @override
  Widget build(BuildContext context) {
    final net = bets.fold<double>(0, (sum, b) => sum + b.profit);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'results',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '${net >= 0 ? '+' : ''}${net.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: net >= 0 ? Tokens.success : Tokens.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space3),
            const Divider(),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: bets.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, i) => _ResultRow(bet: bets[i]),
              ),
            ),
            const SizedBox(height: Tokens.space3),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: Tokens.accent,
                foregroundColor: Tokens.onFill,
              ),
              child: const Text('CONTINUE'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.bet});

  final PlayerBet bet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  bet.fixture,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${bet.selection.name} @ ${bet.taken} · '
                  'finished ${bet.result}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: Tokens.space3),
          Text(
            '${bet.won ? '+' : ''}${bet.profit.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: bet.won ? Tokens.success : Tokens.danger,
            ),
          ),
        ],
      ),
    );
  }
}
