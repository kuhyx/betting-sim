import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/state/game_save.dart';
import 'package:betting_sim/state/ledger.dart';
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

Future<void> _openFeed(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.forum));
  await tester.pumpAndSettle();
}

void main() {
  group('the feed', () {
    testWidgets('carries a page of opinion on every fixture', (tester) async {
      await _mount(tester);
      await _openFeed(tester);

      // Twelve people, ten fixtures. The first thread is on screen.
      expect(find.textContaining('@'), findsWidgets);
      expect(find.textContaining(' v '), findsWidgets);
      expect(find.text('HOME'), findsWidgets);
    });

    testWidgets('says nothing about who is any good', (tester) async {
      await _mount(tester);
      await _openFeed(tester);
      await tester.tap(find.text('your records'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('nothing in the game will tell you'),
        findsOneWidget,
      );
    });

    testWidgets('starts keeping records once calls settle', (tester) async {
      await _mount(tester);
      await tester.tap(find.text('SKIP MATCHDAY'));
      await tester.pumpAndSettle();

      await _openFeed(tester);
      await tester.tap(find.text('your records'));
      await tester.pumpAndSettle();

      // One row per tipster, each with ten settled calls behind it.
      expect(find.textContaining('/10'), findsNWidgets(12));
      expect(find.textContaining('flat 10 on every call'), findsOneWidget);
    });

    testWidgets('can go back to the posts', (tester) async {
      await _mount(tester);
      await _openFeed(tester);
      await tester.tap(find.text('your records'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('posts'));
      await tester.pumpAndSettle();

      expect(find.text('your records'), findsOneWidget);
      expect(find.textContaining('@'), findsWidgets);
    });
  });

  group('TipsterLedger', () {
    test('is rebuilt by replaying, never stored', () {
      // A save carries no notebook: fromSave re-plays every matchday, and
      // every matchday folds its tips back in.
      final original = GameState();
      for (var i = 0; i < 3; i++) {
        original.advanceDay();
      }
      final restored = GameState.fromSave(original.toSave());

      expect(restored.ledger.standings, hasLength(12));
      for (final row in original.ledger.standings) {
        final same = restored.ledger.recordFor(row.tipsterId);
        expect(same.tips, row.record.tips);
        expect(same.hits, row.record.hits);
        expect(same.profit, row.record.profit);
      }
    });

    test('ranks by what following them returned, not by strike rate', () {
      // A tipster who only ever backs odds-on favourites is right most weeks
      // and still loses money. Sorting by hits would put them top.
      final ledger = TipsterLedger();
      final market = const Bookmaker().price(
        const OutcomeProbs(home: 0.8, draw: 0.12, away: 0.08),
      );
      const homeWin = MatchResult(
        homeScore: 1,
        awayScore: 0,
        events: <MatchEvent>[],
      );
      const awayWin = MatchResult(
        homeScore: 0,
        awayScore: 1,
        events: <MatchEvent>[],
      );

      Tip tip(int id, Selection selection) => Tip(
        tipsterId: id,
        handle: '@t$id',
        selection: selection,
        believedProbability: 0.5,
        confidence: 0.5,
        text: '',
      );

      // 0 backs the short favourite and is right three times in four.
      for (final result in <MatchResult>[homeWin, homeWin, homeWin, awayWin]) {
        ledger.record(<Tip>[tip(0, Selection.home)], result, market);
      }
      // 1 backs the big price and is right once in four.
      for (final result in <MatchResult>[awayWin, homeWin, homeWin, homeWin]) {
        ledger.record(<Tip>[tip(1, Selection.away)], result, market);
      }

      expect(ledger.recordFor(0).strikeRate, 0.75);
      expect(ledger.recordFor(1).strikeRate, 0.25);
      expect(ledger.recordFor(0).roi, lessThan(0));
      expect(ledger.recordFor(1).roi, greaterThan(0));
      expect(ledger.standings.first.tipsterId, 1);
    });

    test('has nothing to say before anyone has been checked', () {
      final ledger = TipsterLedger();
      expect(ledger.standings, isEmpty);
      expect(ledger.recordFor(3).tips, 0);
      expect(ledger.recordFor(3).strikeRate, isNull);
      expect(ledger.recordFor(3).roi, isNull);
    });
  });
}
