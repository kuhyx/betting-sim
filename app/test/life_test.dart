import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/state/game_save.dart';
import 'package:betting_sim/state/save_store.dart';
import 'package:betting_sim/ui/home_shell.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_engine/league_engine.dart';

Future<void> _mount(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1000, 1800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: HomeShell(showDebugTuning: false, store: MemorySaveStore()),
    ),
  );
  await tester.pump();
  await tester.tap(find.byIcon(Icons.home));
  await tester.pumpAndSettle();
}

List<Activity> _shiftAndBed() => <Activity>[
  for (var i = 0; i < 8; i++) Activity.sleep,
  Activity.eat,
  Activity.eat,
  for (var i = 0; i < 8; i++) Activity.work,
];

void main() {
  group('the life tab', () {
    testWidgets('opens on the first day with a full budget of hours', (
      tester,
    ) async {
      await _mount(tester);

      expect(find.text('Mon wk1'), findsOneWidget);
      expect(find.text('24 hours left'), findsOneWidget);
      expect(find.text('energy'), findsOneWidget);
      expect(find.text('stress'), findsOneWidget);
      expect(find.textContaining('rent is 320'), findsOneWidget);
    });

    testWidgets('spending an hour takes it off the budget', (tester) async {
      await _mount(tester);

      await tester.tap(find.byTooltip('an hour of work a shift'));
      await tester.pump();
      expect(find.text('23 hours left'), findsOneWidget);
      expect(find.text('1h'), findsOneWidget);

      await tester.tap(find.text('START OVER'));
      await tester.pump();
      expect(find.text('24 hours left'), findsOneWidget);
    });

    testWidgets('getting through the day moves the clock', (tester) async {
      await _mount(tester);

      await tester.tap(find.text('GET THROUGH THE DAY'));
      await tester.pumpAndSettle();

      expect(find.text('Tue wk1'), findsOneWidget);
      expect(find.text('24 hours left'), findsOneWidget);
    });

    testWidgets('the shop sells hours and never an edge', (tester) async {
      await _mount(tester);
      await tester.tap(find.text('shop'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('nothing here makes you better at betting'),
        findsOneWidget,
      );
      expect(find.text('a bicycle'), findsOneWidget);

      await tester.tap(find.text('180'));
      await tester.pumpAndSettle();
      expect(find.text('bought'), findsOneWidget);

      await tester.tap(find.text('today'));
      await tester.pumpAndSettle();
      expect(find.text('25 hours left'), findsOneWidget);
    });
  });

  group('the clock', () {
    test('a round is played on the Saturday you reach, not on a button', () {
      final game = GameState();
      expect(game.day, 0);

      for (var i = 0; i < 5; i++) {
        expect(game.liveDay(_shiftAndBed()), isFalse, reason: 'day $i');
      }
      // Six days in: the Saturday.
      expect(game.liveDay(_shiftAndBed()), isTrue);
      expect(game.day, 1);
      expect(game.life.dayOfSeason, 6);
    });

    test('working pays and living costs', () {
      final worker = GameState()..liveDay(_shiftAndBed());
      final layabout = GameState()..liveDay(<Activity>[]);

      expect(worker.bankroll, greaterThan(layabout.bankroll));
      expect(worker.life.needs.stress, greaterThan(0));
      expect(layabout.life.needs.energy, lessThan(1));
    });

    test('the rent comes out on Friday, ready or not', () {
      final game = GameState();
      for (var i = 0; i < 4; i++) {
        game.liveDay(<Activity>[]);
      }
      final before = game.bankroll;
      game.liveDay(<Activity>[]); // Friday
      expect(game.bankroll, lessThan(before - 300));
      expect(game.life.arrears, 0);
    });

    test('missing it twice ends the run', () {
      // The stake the game was missing: the bankroll now has a floor you can
      // fall through, and falling through it is the end.
      final game = GameState();
      game.purse.adjust(-game.bankroll);
      expect(game.bankroll, 0);

      for (var day = 0; day < 20 && game.life.running; day++) {
        game.liveDay(<Activity>[]);
      }
      expect(game.life.ending, RunEnding.evicted);
      expect(game.seasonOver, isTrue);
      // And nothing more happens.
      final frozen = game.life.dayOfSeason;
      game.liveDay(<Activity>[]);
      expect(game.life.dayOfSeason, frozen);
    });
  });

  group('a life and the save', () {
    test('is stored, because how you spent Tuesday is not in the seed', () {
      final game = GameState();
      for (var i = 0; i < 9; i++) {
        game.liveDay(_shiftAndBed());
      }
      game.buy(catalogue.first);

      final restored = GameState.fromSave(game.toSave());
      expect(restored.life.dayOfSeason, game.life.dayOfSeason);
      expect(restored.life.needs.energy, closeTo(game.life.needs.energy, 1e-9));
      expect(restored.life.needs.stress, closeTo(game.life.needs.stress, 1e-9));
      expect(restored.life.owned, game.life.owned);
      expect(restored.life.arrears, game.life.arrears);
      expect(restored.bankroll, closeTo(game.bankroll, 1e-9));
      expect(restored.day, game.day);
    });

    test('the shopping keeps giving hours back after a restore', () {
      final game = GameState()..buy(catalogue.first);
      final restored = GameState.fromSave(game.toSave());
      expect(restored.life.hoursToday, game.life.hoursToday);
      expect(restored.life.hoursToday, greaterThan(24));
    });
  });
}
