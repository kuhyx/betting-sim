import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/state/save_store.dart';
import 'package:betting_sim/ui/home_shell.dart';
import 'package:betting_sim/ui/match_screen.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_engine/league_engine.dart';

Future<void> _mount(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1000, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: HomeShell(showDebugTuning: false, store: MemorySaveStore()),
    ),
  );
  await tester.pump();
}

void main() {
  group('watching a match', () {
    testWidgets('is only offered once something has been played', (
      tester,
    ) async {
      await _mount(tester);
      expect(find.byIcon(Icons.slow_motion_video), findsNothing);

      await tester.tap(find.text('SKIP MATCHDAY'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.slow_motion_video), findsOneWidget);
    });

    testWidgets('lists the round just played and opens one', (tester) async {
      await _mount(tester);
      await tester.tap(find.text('SKIP MATCHDAY'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.slow_motion_video));
      await tester.pumpAndSettle();
      expect(find.text('last matchday'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsNWidgets(10));

      await tester.tap(find.byIcon(Icons.play_circle_outline).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('full-time stats at 90′'), findsOneWidget);
    });

    testWidgets('runs a clock, then reveals the box score at full time', (
      tester,
    ) async {
      final game = GameState()..advanceDay();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: MatchScreen(match: game.played.first),
        ),
      );
      await tester.pump();

      // The clock is running, and the stats are still hidden.
      expect(find.text("0'"), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.textContaining("'"), findsWidgets);
      expect(find.text('full-time stats at 90′'), findsOneWidget);

      await tester.tap(find.text('FULL TIME'));
      await tester.pumpAndSettle();

      expect(find.text('full time'), findsOneWidget);
      expect(find.text('shots'), findsOneWidget);
      expect(find.text('after the break'), findsOneWidget);
      expect(find.text('possession'), findsOneWidget);
      expect(find.text('WATCH AGAIN'), findsOneWidget);

      // The score shown is counted from the events on screen, so at full
      // time it must equal the result the bet was settled against.
      final result = game.played.first.result;
      expect(
        find.text('${result.homeScore} - ${result.awayScore}'),
        findsOneWidget,
      );
    });

    testWidgets('watching again rewinds to kick-off', (tester) async {
      final game = GameState()..advanceDay();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: MatchScreen(match: game.played.first),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('FULL TIME'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('WATCH AGAIN'));
      await tester.pump();
      expect(find.text('0 - 0'), findsOneWidget);

      await tester.tap(find.text('PAUSE'));
      await tester.pumpAndSettle();
      expect(find.text('RESUME'), findsOneWidget);
    });

    testWidgets('names whoever scored', (tester) async {
      final game = GameState()..advanceDay();
      final scoring = game.played.firstWhere(
        (m) => m.result.homeScore + m.result.awayScore > 0,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: MatchScreen(match: scoring),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('FULL TIME'));
      await tester.pumpAndSettle();

      // Every goal on screen is credited to a real player. "unknown" is the
      // fallback for a club with nobody available, which is not this match.
      expect(find.textContaining('GOAL —'), findsWidgets);
      expect(find.textContaining('unknown'), findsNothing);

      final timeline = const MatchNarrator().narrate(
        scoring.context,
        scoring.result,
      );
      final squad = <int>{
        ...scoring.home.players.map((p) => p.id),
        ...scoring.away.players.map((p) => p.id),
      };
      for (final goal in timeline.events.whereType<GoalEvent>()) {
        expect(squad, contains(goal.playerId));
      }
    });
  });
}
