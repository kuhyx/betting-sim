import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/ui/odds_button.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// One fixture: the two clubs, three prices, and the player's stake.
class FixtureTile extends StatelessWidget {
  /// Creates a fixture tile.
  const FixtureTile({
    required this.card,
    required this.format,
    required this.staked,
    required this.onStake,
    super.key,
  });

  /// The fixture and its market.
  final FixtureCard card;

  /// How prices are rendered.
  final OddsFormat format;

  /// The player's pick on this fixture, if any.
  final ({Selection selection, double stake})? staked;

  /// Called when a price is tapped.
  final void Function(Selection selection) onStake;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${card.home.name}  v  ${card.away.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Tokens.space1),
            Text(
              _conditions(card.context),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Tokens.space3),
            Row(
              children: <Widget>[
                OddsButton(
                  label: 'HOME',
                  odds: card.market.priceOf(Selection.home),
                  format: format,
                  selected: staked?.selection == Selection.home,
                  onTap: () => onStake(Selection.home),
                ),
                const SizedBox(width: Tokens.space2),
                OddsButton(
                  label: 'DRAW',
                  odds: card.market.priceOf(Selection.draw),
                  format: format,
                  selected: staked?.selection == Selection.draw,
                  onTap: () => onStake(Selection.draw),
                ),
                const SizedBox(width: Tokens.space2),
                OddsButton(
                  label: 'AWAY',
                  odds: card.market.priceOf(Selection.away),
                  format: format,
                  selected: staked?.selection == Selection.away,
                  onTap: () => onStake(Selection.away),
                ),
              ],
            ),
            if (staked != null) ...<Widget>[
              const SizedBox(height: Tokens.space2),
              Text(
                'staked ${staked!.stake.toStringAsFixed(0)} '
                'to return ${_potentialReturn().toStringAsFixed(2)}',
                style: const TextStyle(color: Tokens.accent, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _potentialReturn() {
    final pick = staked!;
    return pick.stake * card.market.priceOf(pick.selection).decimal;
  }

  /// The publicly observable team news.
  ///
  /// Weather is shown because it is public; fatigue and morale are NOT, and
  /// never will be -- reading those from results is the game.
  String _conditions(MatchContext ctx) {
    final weather = switch (ctx.weather) {
      Weather.clear => 'clear',
      Weather.rain => 'rain',
      Weather.storm => 'storm',
    };
    return '${card.home.town} · $weather';
  }
}
