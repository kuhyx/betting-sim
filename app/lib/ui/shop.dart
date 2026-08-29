import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// Four things you can buy, all of them time.
///
/// Nothing here improves a price, a probability or a scoreline. Selling the
/// edge would sell the only thing the game is about -- what money buys is
/// hours, and hours are what you read the feed with.
class Shop extends StatelessWidget {
  /// Creates the shop over [game].
  const Shop({required this.game, super.key});

  /// The game being played.
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: <Widget>[
        Text(
          'nothing here makes you better at betting. it buys hours.',
          style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
        ),
        const SizedBox(height: Tokens.space4),
        for (final item in catalogue)
          _Item(
            item: item,
            owned: game.life.owned.contains(item.id),
            affordable: game.bankroll >= item.cost,
            onBuy: () => game.buy(item),
          ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.item,
    required this.owned,
    required this.affordable,
    required this.onBuy,
  });

  final Purchase item;
  final bool owned;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.space3),
      padding: const EdgeInsets.all(Tokens.space4),
      color: Tokens.inkRaised1,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.name, style: text.bodyMedium),
                Text(
                  item.blurb,
                  style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
                ),
              ],
            ),
          ),
          if (owned)
            Text(
              'bought',
              style: text.bodySmall?.copyWith(color: Tokens.success),
            )
          else
            TextButton(
              onPressed: affordable ? onBuy : null,
              child: Text(
                item.cost.toStringAsFixed(0),
                style: TextStyle(
                  color: affordable ? Tokens.accent : Tokens.lineDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
