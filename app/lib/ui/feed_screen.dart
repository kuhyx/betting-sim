import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/ui/tipster_standings.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// What the internet is saying about today's card.
///
/// Fictional, and generated from the same seed tree as the league: the sport,
/// the clubs and the money are invented, so the people arguing about them are
/// too. Nothing here makes a network call.
class FeedScreen extends StatefulWidget {
  /// Creates the feed over [game].
  const FeedScreen({required this.game, super.key});

  /// The game being played.
  final GameState game;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _showRecords = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fixtures = widget.game.fixtures;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Tokens.inkRaised1,
        title: Text('feed', style: text.headlineSmall),
        actions: <Widget>[
          TextButton(
            onPressed: () => setState(() => _showRecords = !_showRecords),
            child: Text(
              _showRecords ? 'posts' : 'your records',
              style: const TextStyle(color: Tokens.accent),
            ),
          ),
        ],
      ),
      body: _showRecords
          ? TipsterStandings(
              ledger: widget.game.ledger,
              tipsters: widget.game.tipsters,
            )
          : _Posts(fixtures: fixtures),
    );
  }
}

class _Posts extends StatelessWidget {
  const _Posts({required this.fixtures});

  final List<FixtureCard> fixtures;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (fixtures.isEmpty) {
      return Center(
        child: Text(
          'the season is over. everyone has gone quiet.',
          style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(Tokens.space4),
      itemCount: fixtures.length,
      itemBuilder: (_, i) => _FixtureThread(card: fixtures[i]),
    );
  }
}

class _FixtureThread extends StatelessWidget {
  const _FixtureThread({required this.card});

  final FixtureCard card;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${card.home.name} v ${card.away.name}',
            style: text.titleMedium,
          ),
          const SizedBox(height: Tokens.space2),
          for (final tip in card.tips) _Post(tip: tip),
        ],
      ),
    );
  }
}

class _Post extends StatelessWidget {
  const _Post({required this.tip});

  final Tip tip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.space2),
      padding: const EdgeInsets.all(Tokens.space3),
      color: Tokens.inkRaised1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  tip.handle,
                  style: text.bodyMedium?.copyWith(color: Tokens.accent),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.space2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Tokens.lineDark),
                  borderRadius: BorderRadius.circular(Tokens.radiusSmall),
                ),
                child: Text(
                  tip.selection.name.toUpperCase(),
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space2),
          Text(tip.text, style: text.bodySmall),
        ],
      ),
    );
  }
}
