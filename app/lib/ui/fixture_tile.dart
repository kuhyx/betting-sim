import 'dart:async';

import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/ui/odds_button.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// One fixture, sized to fill a grid cell: the clubs, three prices, and the
/// player's stake.
///
/// The prices take whatever height is left after the heading, so the tile
/// holds together at the smallest cell the grid will hand it. The team news
/// is one tap or long-press away on the heading rather than dropped.
class FixtureTile extends StatelessWidget {
  /// Creates a fixture tile.
  const new({
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

  void _showNews(BuildContext context) {
    final text = Theme.of(context).textTheme;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Tokens.inkRaised1,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${card.home.name}  v  ${card.away.name}',
                style: text.titleMedium,
              ),
              const SizedBox(height: Tokens.space1),
              Text(_conditions(card.context), style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pick = staked;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: () => _showNews(context),
              onLongPress: () => _showNews(context),
              child: Text(
                '${card.home.name} v ${card.away.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            for (final (label, selection) in <(String, Selection)>[
              ('HOME', Selection.home),
              ('DRAW', Selection.draw),
              ('AWAY', Selection.away),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: Tokens.space1),
                  child: OddsButton(
                    label: label,
                    odds: card.market.priceOf(selection),
                    format: format,
                    selected: pick?.selection == selection,
                    onTap: () => onStake(selection),
                  ),
                ),
              ),
            if (pick != null)
              Padding(
                padding: const EdgeInsets.only(top: Tokens.space1),
                child: Text(
                  'staked ${pick.stake.toStringAsFixed(0)} '
                  'to return ${_potentialReturn(pick).toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Tokens.accent, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _potentialReturn(({Selection selection, double stake}) pick) =>
      pick.stake * card.market.priceOf(pick.selection).decimal;

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
