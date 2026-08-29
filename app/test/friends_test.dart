import 'package:betting_sim/state/friends.dart';
import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/state/game_save.dart';
import 'package:betting_sim/state/save_store.dart';
import 'package:betting_sim/ui/home_shell.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_engine/league_engine.dart';

Future<void> _mount(WidgetTester tester, {SaveStore? store}) async {
  tester.view
    ..physicalSize = const Size(1000, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: HomeShell(
        showDebugTuning: false,
        store: store ?? MemorySaveStore(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openFriends(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.people));
  await tester.pumpAndSettle();
}

/// A fresh game, with nothing decided yet.
GameState _chatty() => GameState()..records.peers.clear();

void main() {
  group('the friends tab', () {
    testWidgets('shows offers with the three things you can do', (
      tester,
    ) async {
      await _mount(tester);
      await _openFriends(tester);

      expect(find.text("YOU'RE ON"), findsWidgets);
      expect(find.text('HAGGLE'), findsWidgets);
      expect(find.text('LEAVE IT'), findsWidgets);
      expect(find.textContaining('you risk'), findsWidgets);
    });

    testWidgets('accepting shakes on it and shows what you have riding', (
      tester,
    ) async {
      await _mount(tester);
      await _openFriends(tester);

      await tester.tap(find.text("YOU'RE ON").first);
      await tester.pumpAndSettle();

      expect(find.textContaining('shook on'), findsOneWidget);
      expect(find.textContaining('riding on your mates'), findsOneWidget);
    });

    testWidgets('leaving it takes it off the table', (tester) async {
      await _mount(tester);
      await _openFriends(tester);

      await tester.tap(find.text('LEAVE IT').first);
      await tester.pumpAndSettle();

      expect(find.text('left it'), findsOneWidget);
      expect(find.textContaining('riding on your mates'), findsNothing);
    });

    testWidgets('haggling either lands or loses you the bet', (tester) async {
      await _mount(tester);
      await _openFriends(tester);

      await tester.tap(find.text('HAGGLE').first);
      await tester.pumpAndSettle();

      // One of the two, never neither: a haggle always resolves.
      final landed = find.textContaining('talked them down');
      final walked = find.text('they walked');
      expect(
        landed.evaluate().length + walked.evaluate().length,
        1,
      );
    });

    testWidgets('nothing is owed until something settles', (tester) async {
      await _mount(tester);
      await _openFriends(tester);
      await tester.tap(find.text('who owes who'));
      await tester.pumpAndSettle();

      expect(find.textContaining('starts adding up here'), findsOneWidget);
    });

    testWidgets('a settled bet lands in the book', (tester) async {
      await _mount(tester);
      await _openFriends(tester);
      await tester.tap(find.text("YOU'RE ON").first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.sports_soccer));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SKIP MATCHDAY'));
      await tester.pumpAndSettle();

      await _openFriends(tester);
      await tester.tap(find.text('who owes who'));
      await tester.pumpAndSettle();

      expect(find.text('1 bet'), findsOneWidget);
    });
  });

  group('PeerSlip', () {
    test('a haggle is a real decision, not a free reroll', () {
      final game = _chatty();
      final card = game.fixtures.firstWhere((c) => c.proposals.isNotEmpty);
      final terms = card.proposals.first;

      final shook = game.records.peers.haggle(card.index, 0, terms);
      expect(game.records.peers.settled(card.index, 0), isTrue);
      if (shook) {
        final struck = game.records.peers.struckOn(card.index, 0)!;
        expect(struck.odds.decimal, lessThan(terms.proposal.odds.decimal));
      } else {
        // They walked. The bet is gone, not merely unaccepted.
        expect(game.records.peers.struckOn(card.index, 0), isNull);
      }
    });

    test('keys do not collide across fixtures', () {
      expect(PeerSlip.keyFor(0, 1), isNot(PeerSlip.keyFor(1, 0)));
      expect(PeerSlip.keyFor(3, 7), PeerSlip.keyFor(3, 7));
    });

    test('clears itself for the next matchday', () {
      final game = _chatty();
      final card = game.fixtures.firstWhere((c) => c.proposals.isNotEmpty);
      game.records.peers.accept(card.index, 0, card.proposals.first.proposal);
      expect(game.records.peers.count, 1);

      game.advanceDay();
      expect(game.records.peers.count, 0);
      expect(game.records.peers.atRisk, 0);
    });
  });

  group('friend bets and the save', () {
    test('are stored, because a handshake is a choice', () {
      // Everything else in a save is recoverable by replaying the seed. Which
      // offers you took is not: nothing in the seed knows what you said.
      final game = GameState();
      for (var day = 0; day < 3; day++) {
        final card = game.fixtures.firstWhere(
          (c) => c.proposals.isNotEmpty,
          orElse: () => game.fixtures.first,
        );
        if (card.proposals.isNotEmpty) {
          game.records.peers.accept(
            card.index,
            0,
            card.proposals.first.proposal,
          );
        }
        game.advanceDay();
      }
      expect(game.peerHistory, isNotEmpty);

      final restored = GameState.fromSave(game.toSave());
      expect(restored.peerHistory.length, game.peerHistory.length);
      expect(restored.bankroll, closeTo(game.bankroll, 1e-9));
      for (final bet in game.peerHistory) {
        expect(
          restored.records.friendBook.balanceWith(bet.friendId),
          closeTo(game.records.friendBook.balanceWith(bet.friendId), 1e-9),
        );
      }
    });

    test('settle in your favour when their pick loses', () {
      const proposal = FriendProposal(
        friendId: 0,
        name: 'Mate',
        selection: Selection.home,
        stake: 20,
        odds: Odds(3),
        message: '',
      );
      const theyLose = MatchResult(
        homeScore: 0,
        awayScore: 1,
        events: <MatchEvent>[],
      );
      expect(settleProposal(proposal, theyLose), 20);

      final book = FriendBook()
        ..add(
          const PeerBet(
            friendId: 0,
            name: 'Mate',
            fixture: 'A v B',
            selection: Selection.home,
            stake: 20,
            odds: Odds(3),
            profit: 20,
            result: '0-1',
            haggled: false,
          ),
        );
      expect(book.balanceWith(0), 20);
      expect(book.betsWith(0), 1);
      expect(book.standings.single.friendId, 0);
      expect(book.balanceWith(9), 0);
      expect(FriendBook().standings, isEmpty);
    });
  });
}
