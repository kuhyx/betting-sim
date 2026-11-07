import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/state/friends.dart';
import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/state/game_save.dart';
import 'package:betting_sim/state/save.dart';
import 'package:betting_sim/state/save_store.dart';
import 'package:betting_sim/ui/home_shell.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_engine/league_engine.dart';

/// A game whose history is [count] settled bets, each at [clv].
GameState _record(int count, double clv) {
  final fresh = GameState().toSave();
  return GameState.fromSave(
    SaveData(
      masterSeed: fresh.masterSeed,
      tuning: fresh.tuning,
      day: 0,
      bets: <PlayerBet>[
        for (var i = 0; i < count; i++)
          PlayerBet(
            fixture: 'A v B',
            selection: Selection.home,
            stake: 10,
            taken: const Odds(2),
            profit: 0,
            result: '1-1',
            closingLineValue: clv,
          ),
      ],
      peerBets: const <PeerBet>[],
      life: fresh.life,
    ),
  );
}

void main() {
  group('the book limits a sharp player', () {
    test('twenty bets beating the close cut the stake limit', () {
      final game = _record(20, 0.05);
      expect(game.restricted, isTrue);
      expect(game.stakeCap, lessThan(50));
      expect(game.stakeCap, game.stakeCap.floorToDouble());
      game.stake(0, Selection.home, 50);
      expect(game.slip[0]!.stake, game.stakeCap);
    });

    test('nineteen are not enough to judge on', () {
      final game = _record(19, 0.05);
      expect(game.restricted, isFalse);
      expect(game.stakeCap, 50);
      // The book's own limit still holds for everybody.
      game.stake(0, Selection.home, 100);
      expect(game.slip[0]!.stake, 50);
    });

    test('an ordinary record keeps the full limit', () {
      final game = _record(20, -0.01)..stake(0, Selection.home, 50);
      expect(game.restricted, isFalse);
      expect(game.slip[0]!.stake, 50);
    });

    test('a save remembers the restriction', () {
      final game = _record(20, 0.05);
      final back = GameState.fromSave(SaveData.decode(game.toSave().encode())!);
      expect(back.restricted, isTrue);
      expect(back.stakeCap, game.stakeCap);
    });
  });

  group('the stake picker', () {
    Future<void> mount(WidgetTester tester, GameState game) async {
      tester.view
        ..physicalSize = const Size(1000, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: HomeShell(
            showDebugTuning: false,
            store: MemorySaveStore(game.toSave().encode()),
          ),
        ),
      );
      await tester.pump();
    }

    bool tappable(WidgetTester tester, String label) =>
        tester
            .widget<InkWell>(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(InkWell),
              ),
            )
            .onTap !=
        null;

    testWidgets('greys out what the book will not take, and says so', (
      tester,
    ) async {
      final game = _record(20, 0.05);
      await mount(tester, game);
      final cap = game.stakeCap.toStringAsFixed(0);
      expect(find.text('limits cut to $cap'), findsOneWidget);
      expect(tappable(tester, '50'), isFalse);
      expect(tappable(tester, '5'), isTrue);
    });

    testWidgets('highlights the stake that will go on, not a greyed one', (
      tester,
    ) async {
      // A big edge pins the cap under the default 10 chip.
      final game = _record(20, 0.5);
      expect(game.stakeCap, lessThan(10));
      await mount(tester, game);
      Color fill(String label) =>
          ((tester
                      .widget<Container>(
                        find
                            .ancestor(
                              of: find.text(label),
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration!)
                  as BoxDecoration)
              .color!;
      expect(fill('10'), isNot(Tokens.accent));
      expect(fill('5'), Tokens.accent);
    });

    testWidgets('offers everything to an ordinary player', (tester) async {
      await mount(tester, _record(20, -0.01));
      expect(find.textContaining('limits cut'), findsNothing);
      expect(tappable(tester, '50'), isTrue);
    });
  });
}
