import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/state/game_save.dart';
import 'package:betting_sim/state/save.dart';
import 'package:betting_sim/state/save_store.dart';
import 'package:betting_sim/ui/home_shell.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_engine/league_engine.dart';

/// A weekday: bed, two meals, a shift, and [extra] on top.
List<Activity> _day(List<Activity> extra) => <Activity>[
  for (var i = 0; i < 8; i++) Activity.sleep,
  Activity.eat,
  Activity.eat,
  for (var i = 0; i < 8; i++) Activity.work,
  ...extra,
];

Future<void> _openFeed(WidgetTester tester, GameState game) async {
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
  await tester.tap(find.byIcon(Icons.forum));
  await tester.pumpAndSettle();
}

void main() {
  group('the feed is paid for in hours', () {
    test('a new week starts locked, two hours short', () {
      final game = GameState();
      expect(game.feedUnlocked, isFalse);
      expect(game.studyHoursNeeded, 2);
    });

    test('two hours reading up open it', () {
      final game = GameState()..liveDay(_day(<Activity>[Activity.study]));
      expect(game.feedUnlocked, isFalse);
      expect(game.studyHoursNeeded, 1);
      game.liveDay(_day(<Activity>[Activity.study]));
      expect(game.feedUnlocked, isTrue);
      expect(game.studyHoursNeeded, 0);
    });

    test('watching matches does not count', () {
      final game = GameState()
        ..liveDay(<Activity>[
          for (var i = 0; i < 8; i++) Activity.sleep,
          for (var i = 0; i < 8; i++) Activity.watch,
        ]);
      expect(game.feedUnlocked, isFalse);
    });

    test('the round closes it again for the next card', () {
      final game = GameState()
        ..liveDay(_day(<Activity>[Activity.study, Activity.study]))
        ..advanceDay();
      expect(game.day, 1);
      expect(game.feedUnlocked, isFalse);
    });

    test("a save keeps the week's reading", () {
      final game = GameState()
        ..liveDay(_day(<Activity>[Activity.study, Activity.study]));
      final back = GameState.fromSave(SaveData.decode(game.toSave().encode())!);
      expect(back.feedUnlocked, isTrue);
    });

    test('a version 3 save still loads, with nothing read yet', () {
      final v4 = GameState().toSave().encode();
      final v3 = v4
          .replaceFirst('"version":4', '"version":3')
          .replaceFirst(RegExp(r',"studyHours":\d+'), '');
      expect(v3, isNot(contains('studyHours')));
      final save = SaveData.decode(v3);
      expect(save, isNotNull);
      expect(save!.life.studyHours, 0);
    });
  });

  group('the feed tab', () {
    testWidgets('says how many hours it still wants, and shows no posts', (
      tester,
    ) async {
      await _openFeed(tester, GameState());
      expect(find.textContaining('2 more hours'), findsOneWidget);
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('says the season is over, not that it wants hours', (
      tester,
    ) async {
      final game = GameState();
      while (!game.seasonOver) {
        game.advanceDay();
      }
      await _openFeed(tester, game);
      expect(find.textContaining('the season is over'), findsOneWidget);
      expect(find.textContaining('more hours'), findsNothing);
    });

    testWidgets('shows the posts once the hours are in', (tester) async {
      final game = GameState()
        ..liveDay(_day(<Activity>[Activity.study, Activity.study]));
      await _openFeed(tester, game);
      expect(find.textContaining('more hours'), findsNothing);
      expect(find.textContaining('@'), findsWidgets);
    });
  });
}
