import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/state/friends.dart';
import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/ui/friend_standings.dart';
import 'package:betting_sim/ui/proposal_card.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';

/// What your friends want on today's card, and what you said about it.
///
/// The offers are invented and generated from the seed tree, like everything
/// else. Nothing here talks to another person or another machine.
class FriendsScreen extends StatefulWidget {
  /// Creates the screen over [game].
  const FriendsScreen({required this.game, super.key});

  /// The game being played.
  final GameState game;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  /// What happened to each proposal, for the ones already dealt with.
  final Map<int, String> _outcomes = <int, String>{};
  bool _showBook = false;

  PeerSlip get _peers => widget.game.records.peers;

  void _decide(int fixtureIndex, int index, FixtureCard card, String how) {
    final terms = card.proposals[index];
    final key = PeerSlip.keyFor(fixtureIndex, index);
    setState(() {
      switch (how) {
        case 'accept':
          _peers.accept(fixtureIndex, index, terms.proposal);
          _outcomes[key] =
              'shook on '
              '${terms.proposal.odds.decimal.toStringAsFixed(2)}';
        case 'haggle':
          final struck = _peers.haggle(fixtureIndex, index, terms);
          final got = _peers.struckOn(fixtureIndex, index);
          _outcomes[key] = struck
              ? 'talked them down to '
                    '${got!.odds.decimal.toStringAsFixed(2)}'
              : 'they walked';
        case _:
          _peers.reject(fixtureIndex, index);
          _outcomes[key] = 'left it';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fixtures = widget.game.fixtures;
    final open = <Widget>[];

    for (final card in fixtures) {
      for (var i = 0; i < card.proposals.length; i++) {
        open.add(
          ProposalCard(
            terms: card.proposals[i],
            fixture: '${card.home.name} v ${card.away.name}',
            outcome: _outcomes[PeerSlip.keyFor(card.index, i)],
            onAccept: () => _decide(card.index, i, card, 'accept'),
            onHaggle: () => _decide(card.index, i, card, 'haggle'),
            onReject: () => _decide(card.index, i, card, 'reject'),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Tokens.inkRaised1,
        title: Text('friends', style: text.headlineSmall),
        actions: <Widget>[
          TextButton(
            onPressed: () => setState(() => _showBook = !_showBook),
            child: Text(
              _showBook ? 'offers' : 'who owes who',
              style: const TextStyle(color: Tokens.accent),
            ),
          ),
        ],
      ),
      body: _showBook
          ? FriendStandings(
              book: widget.game.records.friendBook,
              friends: widget.game.records.friends,
            )
          : _Offers(offers: open, atRisk: _peers.atRisk),
    );
  }
}

class _Offers extends StatelessWidget {
  const _Offers({required this.offers, required this.atRisk});

  final List<Widget> offers;
  final double atRisk;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (offers.isEmpty) {
      return Center(
        child: Text(
          'nobody fancies anything this week.',
          style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
        ),
      );
    }
    return Column(
      children: <Widget>[
        if (atRisk > 0)
          Container(
            width: double.infinity,
            color: Tokens.inkRaised1,
            padding: const EdgeInsets.all(Tokens.space3),
            child: Text(
              'you have ${atRisk.toStringAsFixed(2)} riding on your mates',
              style: text.bodySmall?.copyWith(color: Tokens.accent),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Tokens.space4),
            children: offers,
          ),
        ),
      ],
    );
  }
}
