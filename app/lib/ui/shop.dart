import 'dart:async';

import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// Four things you can buy, all of them time.
///
/// Nothing here improves a price, a probability or a scoreline. Selling the
/// edge would sell the only thing the game is about -- what money buys is
/// hours, and hours are what you read the feed with.
class Shop extends StatelessWidget {
  /// Creates the shop over [game].
  const new({required this.game, super.key});

  /// The game being played.
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space4,
            0,
            Tokens.space4,
            Tokens.space3,
          ),
          child: Text(
            'nothing here makes you better at betting. it buys hours.',
            style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
          ),
        ),
        Expanded(
          child: FitGrid(
            itemCount: catalogue.length,
            itemBuilder: (_, i) => _Item(
              item: catalogue[i],
              owned: game.life.owned.contains(catalogue[i].id),
              affordable: game.bankroll >= catalogue[i].cost,
              onBuy: () => game.buy(catalogue[i]),
            ),
          ),
        ),
      ],
    );
  }
}

/// A tile: the name and the price. The blurb and the buy button are one tap
/// away, so a 180 purchase is never one stray touch.
class _Item extends StatelessWidget {
  const new({
    required this.item,
    required this.owned,
    required this.affordable,
    required this.onBuy,
  });

  final Purchase item;
  final bool owned;
  final bool affordable;
  final VoidCallback onBuy;

  void _open(BuildContext context) {
    final text = Theme.of(context).textTheme;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Tokens.inkRaised1,
        builder: (sheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.name, style: text.titleMedium),
                const SizedBox(height: Tokens.space1),
                Text(
                  item.blurb,
                  style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
                ),
                const SizedBox(height: Tokens.space3),
                if (!owned)
                  TextButton(
                    onPressed: affordable
                        ? () {
                            Navigator.of(sheet).pop();
                            onBuy();
                          }
                        : null,
                    child: Text(
                      item.cost.toStringAsFixed(0),
                      style: TextStyle(
                        color: affordable ? Tokens.accent : Tokens.lineDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(Tokens.radius),
      child: Container(
        padding: const EdgeInsets.all(Tokens.space2),
        decoration: BoxDecoration(
          color: Tokens.inkRaised1,
          borderRadius: BorderRadius.circular(Tokens.radius),
          border: Border.all(color: owned ? Tokens.success : Tokens.lineDark),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium,
            ),
            const SizedBox(height: Tokens.space1),
            if (owned)
              Text(
                'bought',
                style: text.bodySmall?.copyWith(color: Tokens.success),
              )
            else
              Text(
                item.cost.toStringAsFixed(0),
                style: text.bodySmall?.copyWith(
                  color: affordable ? Tokens.accent : Tokens.mutedOnDark,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
