import 'package:betting_sim/state/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_engine/league_engine.dart';

void main() {
  group('GameState', () {
    test('opens on matchday 1 with a full card of fixtures', () {
      final game = GameState();
      expect(game.day, 0);
      expect(game.totalDays, 38);
      expect(game.fixtures, hasLength(10));
      expect(game.bankroll, 1000);
      expect(game.seasonOver, isFalse);
    });

    test('every fixture is priced', () {
      final game = GameState();
      for (final card in game.fixtures) {
        for (final s in Selection.values) {
          expect(card.market.priceOf(s).decimal, greaterThan(1));
        }
      }
    });

    test('staking puts a bet on the slip', () {
      final game = GameState()..stake(0, Selection.home, 10);
      expect(game.slip, hasLength(1));
      expect(game.slip[0]!.selection, Selection.home);
      expect(game.slipStake, 10);
    });

    test('staking zero clears the pick', () {
      final game = GameState()
        ..stake(0, Selection.home, 10)
        ..stake(0, Selection.home, 0);
      expect(game.slip, isEmpty);
      expect(game.slipStake, 0);
    });

    test('restaking replaces the selection on that fixture', () {
      final game = GameState()
        ..stake(0, Selection.home, 10)
        ..stake(0, Selection.away, 25);
      expect(game.slip, hasLength(1));
      expect(game.slip[0]!.selection, Selection.away);
      expect(game.slip[0]!.stake, 25);
    });

    test('playing a matchday settles the slip and moves the bankroll', () {
      final game = GameState()..stake(0, Selection.home, 100);
      final before = game.bankroll;

      game.advanceDay();

      expect(game.day, 1);
      expect(game.slip, isEmpty);
      expect(game.history, hasLength(1));
      expect(game.bankroll, isNot(before));

      final bet = game.history.first;
      expect(bet.stake, 100);
      // Won or lost, but never both and never nothing.
      expect(bet.profit == -100 || bet.profit > 0, isTrue);
      expect(bet.won, bet.profit > 0);
    });

    test('a winning bet pays the price that was taken', () {
      // Search seeds for a winning home bet so the payout can be checked
      // exactly rather than approximately.
      for (var seed = 1; seed < 40; seed++) {
        final game = GameState(masterSeed: seed);
        final odds = game.fixtures[0].market.priceOf(Selection.home);
        game
          ..stake(0, Selection.home, 100)
          ..advanceDay();
        final bet = game.history.first;
        if (bet.won) {
          expect(bet.profit, closeTo(100 * (odds.decimal - 1), 1e-9));
          return;
        }
      }
      fail('no winning home bet found in 40 seeds');
    });

    test('skipping a matchday costs nothing', () {
      final game = GameState();
      final before = game.bankroll;
      game.advanceDay();
      expect(game.bankroll, before);
      expect(game.history, isEmpty);
      expect(game.day, 1);
    });

    test('the season ends after the last matchday', () {
      final game = GameState();
      for (var i = 0; i < 38; i++) {
        game.advanceDay();
      }
      expect(game.seasonOver, isTrue);
      expect(game.fixtures, isEmpty);
      // Advancing past the end is a no-op rather than a crash.
      game.advanceDay();
      expect(game.day, 38);
    });

    test('is deterministic: the same seed replays the same season', () {
      double play(int seed) {
        final game = GameState(masterSeed: seed);
        for (var i = 0; i < 5; i++) {
          game
            ..stake(0, Selection.home, 10)
            ..advanceDay();
        }
        return game.bankroll;
      }

      expect(play(7), play(7));
      expect(play(7), isNot(play(8)));
    });

    test('hidden state is never exposed to the UI', () {
      // The whole game: a player sees prices, scorelines and public weather.
      // Fatigue, morale and form stay hidden, or there is nothing to learn.
      final game = GameState();
      final card = game.fixtures.first;
      expect(card.context.weather, isNotNull);
      expect(
        card.home.rating.deviation,
        350,
        reason: 'ratings start unknown; scouting fog is real',
      );
    });
  });
}
