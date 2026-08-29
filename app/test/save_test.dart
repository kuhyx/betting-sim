import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/state/game_save.dart';
import 'package:betting_sim/state/save.dart';
import 'package:betting_sim/state/save_store.dart';
import 'package:betting_sim/state/tuning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_engine/league_engine.dart';

/// Plays [days] matchdays, backing the home side in the first fixture of each.
GameState _played(int days, {int seed = 20260828}) {
  final game = GameState(masterSeed: seed);
  for (var i = 0; i < days; i++) {
    game
      ..stake(0, Selection.home, 25)
      ..advanceDay();
  }
  return game;
}

void main() {
  group('SaveData', () {
    test('round-trips through JSON', () {
      final save = _played(3).toSave();
      final back = SaveData.decode(save.encode())!;

      expect(back.masterSeed, save.masterSeed);
      expect(back.day, 3);
      expect(back.bets, hasLength(save.bets.length));
      expect(back.tuning, save.tuning);
      expect(back.bets.first.fixture, save.bets.first.fixture);
      expect(back.bets.first.taken.decimal, save.bets.first.taken.decimal);
      expect(back.bets.first.selection, save.bets.first.selection);
      expect(back.bets.first.profit, save.bets.first.profit);
      expect(back.bets.first.closingLineValue, isNotNull);
    });

    test('carries the tuning knobs it was played under', () {
      const tuning = Tuning(bookLatentAwareness: 0.4, margin: 0.08);
      final save = GameState(tuning: tuning).toSave();
      expect(SaveData.decode(save.encode())!.tuning, tuning);
    });

    test('refuses anything it cannot read, rather than throwing', () {
      // Every one of these means the same thing: start a new game.
      expect(SaveData.decode(null), isNull);
      expect(SaveData.decode(''), isNull);
      expect(SaveData.decode('not json at all'), isNull);
      expect(SaveData.decode('{"version":999}'), isNull);
      expect(SaveData.decode('{"version":1}'), isNull);
      expect(
        SaveData.decode(
          '{"version":1,"masterSeed":"nope","day":0,'
          '"tuning":{},"bets":[]}',
        ),
        isNull,
      );
    });
  });

  group('GameState.fromSave', () {
    test('replays to the same day, bankroll and history', () {
      final original = _played(5);
      final restored = GameState.fromSave(original.toSave());

      expect(restored.day, original.day);
      expect(restored.bankroll, original.bankroll);
      expect(restored.history, hasLength(original.history.length));
      expect(
        restored.performance.roi,
        closeTo(original.performance.roi!, 1e-12),
      );
      expect(
        restored.performance.averageClv,
        closeTo(original.performance.averageClv!, 1e-12),
      );
    });

    test('reopens the same fixtures at the same prices', () {
      // The real assertion: a save stores no league and no odds, so if the
      // seed tree did not replay exactly, today's card would differ.
      final original = _played(5);
      final restored = GameState.fromSave(original.toSave());

      expect(restored.fixtures, hasLength(original.fixtures.length));
      for (var i = 0; i < original.fixtures.length; i++) {
        final a = original.fixtures[i];
        final b = restored.fixtures[i];
        expect(b.home.name, a.home.name);
        expect(b.away.name, a.away.name);
        for (final selection in Selection.values) {
          expect(
            b.market.priceOf(selection).decimal,
            a.market.priceOf(selection).decimal,
            reason: 'fixture $i ${selection.name}',
          );
        }
      }
    });

    test('a fresh save restores a fresh game', () {
      final restored = GameState.fromSave(GameState().toSave());
      expect(restored.day, 0);
      expect(restored.bankroll, GameState.openingBankroll);
      expect(restored.history, isEmpty);
    });

    test('can still watch the round it left off on', () {
      // Nothing about the matches is stored: replaying the save re-plays the
      // last matchday, so the reports are there to open again.
      final original = _played(3);
      final restored = GameState.fromSave(original.toSave());

      expect(restored.played, hasLength(original.played.length));
      for (var i = 0; i < original.played.length; i++) {
        expect(restored.played[i].scoreline, original.played[i].scoreline);
        expect(restored.played[i].home.name, original.played[i].home.name);
      }
    });

    test('carries the calendar with it', () {
      final game = _played(2);
      expect(game.date.weekday, Weekday.saturday);
      expect(game.date.week, 2);
      expect(GameState.fromSave(game.toSave()).date, game.date);
    });
  });

  group('MemorySaveStore', () {
    test('reads back what was written, and clears', () async {
      final store = MemorySaveStore();
      expect(await store.read(), isNull);

      await store.write('payload');
      expect(await store.read(), 'payload');
      expect(store.raw, 'payload');

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('can start already holding a save', () async {
      expect(await MemorySaveStore('seeded').read(), 'seeded');
    });
  });
}
