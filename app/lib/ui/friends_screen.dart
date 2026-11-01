import 'dart:async';

import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/state/friends.dart';
import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/ui/friend_standings.dart';
import 'package:betting_sim/ui/friend_tile.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// What your friends want on today's card, and what you said about it.
///
/// The offers are invented and generated from the seed tree, like everything
/// else. Nothing here talks to another person or another machine.
class FriendsScreen extends StatefulWidget {
  /// Creates the screen over [game].
  const new({required this.game, super.key});

  /// The game being played.
  final GameState game;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  /// What happened to each proposal, for the ones already dealt with.
  final Map<int, String> _outcomes = <int, String>{};

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

  void _showBook() {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Tokens.inkRaised1,
        isScrollControlled: true,
        builder: (sheet) => SizedBox(
          height: MediaQuery.sizeOf(sheet).height * 0.6,
          child: FriendStandings(
            book: widget.game.records.friendBook,
            friends: widget.game.records.friends,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final offers = <Widget>[
      for (final card in widget.game.fixtures)
        for (var i = 0; i < card.proposals.length; i++)
          FriendTile(
            terms: card.proposals[i],
            fixture: '${card.home.name} v ${card.away.name}',
            outcome: _outcomes[PeerSlip.keyFor(card.index, i)],
            onChoose: (choice) => _decide(card.index, i, card, choice.name),
          ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Tokens.inkRaised1,
        title: Text('friends', style: text.headlineSmall),
        actions: <Widget>[
          TextButton(
            onPressed: _showBook,
            child: const Text(
              'who owes who',
              style: TextStyle(color: Tokens.accent),
            ),
          ),
        ],
      ),
      body: _Offers(offers: offers, atRisk: _peers.atRisk),
    );
  }
}

class _Offers extends StatelessWidget {
  const new({required this.offers, required this.atRisk});

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
          child: FitGrid(
            itemCount: offers.length,
            labelHeight: 32,
            itemBuilder: (_, i) => offers[i],
          ),
        ),
      ],
    );
  }
}
