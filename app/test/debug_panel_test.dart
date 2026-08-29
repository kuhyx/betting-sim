import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/state/performance.dart';
import 'package:betting_sim/state/save_store.dart';
import 'package:betting_sim/state/tuning.dart';
import 'package:betting_sim/ui/debug_panel.dart';
import 'package:betting_sim/ui/home_shell.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_engine/league_engine.dart';

Widget _panel({
  required bool enabled,
  Tuning tuning = const Tuning(),
  Performance? performance,
  ValueChanged<Tuning>? onChanged,
}) {
  return MaterialApp(
    theme: buildTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: DebugTuningPanel(
          tuning: tuning,
          performance: performance ?? Performance(),
          onChanged: onChanged ?? (_) {},
          enabled: enabled,
        ),
      ),
    ),
  );
}

void main() {
  group('DebugTuningPanel', () {
    testWidgets('renders nothing at all when disabled', (tester) async {
      await tester.pumpWidget(_panel(enabled: false));

      expect(find.text(debugPanelTitle), findsNothing);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('shows every knob when enabled', (tester) async {
      await tester.pumpWidget(_panel(enabled: true));

      expect(find.text(debugPanelTitle), findsOneWidget);
      expect(find.text('book awareness'), findsOneWidget);
      expect(find.text('margin'), findsOneWidget);
      expect(find.text('strength scale'), findsOneWidget);
      expect(find.text('fatigue penalty'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(4));
      expect(find.text('0.70'), findsOneWidget);
    });

    testWidgets('an untouched scoreboard shows dashes, not zeroes', (
      tester,
    ) async {
      await tester.pumpWidget(_panel(enabled: true));

      expect(find.text('--'), findsNWidgets(3));
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('a winning scoreboard reads signed and positive', (
      tester,
    ) async {
      final perf = Performance()..record(stake: 10, profit: 2, clv: 0.03);
      await tester.pumpWidget(_panel(enabled: true, performance: perf));

      expect(find.text('+20.00%'), findsOneWidget);
      expect(find.text('+3.00%'), findsOneWidget);
      expect(find.text('100.00%'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a losing scoreboard reads negative', (tester) async {
      final perf = Performance()..record(stake: 10, profit: -10, clv: -0.04);
      await tester.pumpWidget(_panel(enabled: true, performance: perf));

      expect(find.text('-100.00%'), findsOneWidget);
      expect(find.text('-4.00%'), findsOneWidget);
    });

    testWidgets('dragging a slider reports the new tuning', (tester) async {
      Tuning? got;
      await tester.pumpWidget(
        _panel(enabled: true, onChanged: (t) => got = t),
      );

      await tester.drag(find.byType(Slider).first, const Offset(-200, 0));
      await tester.pump();

      expect(got, isNotNull);
      expect(got!.bookLatentAwareness, lessThan(0.7));
      // Only the dragged knob moves.
      expect(got!.margin, const Tuning().margin);
    });

    testWidgets('a value outside a slider range is clamped, not thrown', (
      tester,
    ) async {
      // Guards the Slider assertion that value must sit within [min, max]:
      // the knob ranges are UI choices and could be tightened below a value
      // the engine happily accepts.
      await tester.pumpWidget(
        _panel(enabled: true, tuning: const Tuning(margin: 0.9)),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('0.900'), findsOneWidget);
    });
  });

  group('the knob is wired to the game', () {
    test('awareness changes what the book quotes', () {
      // The point of the whole feature: a different awareness must produce
      // different PRICES from the same seed. If this passed with equal odds
      // the panel would be a placebo.
      //
      // Measured on a matchday well into the season, NOT on matchday 1. Every
      // club starts at a zeroed LatentState, so on day 1 there is no hidden
      // state for the book to be blind to: the informed and unaware views
      // coincide and the blend is a no-op on any fixture whose weather and
      // referee also happen to match. Fatigue and form have to accumulate
      // before the knob has anything to bite on -- which is itself worth
      // knowing while tuning, since day 1 always feels identical.
      final soft = GameState(tuning: const Tuning(bookLatentAwareness: 0.1));
      final sharp = GameState(tuning: const Tuning(bookLatentAwareness: 1));
      addTearDown(soft.dispose);
      addTearDown(sharp.dispose);

      for (var day = 0; day < 5; day++) {
        soft.advanceDay();
        sharp.advanceDay();
      }

      // Same seed, so the same fixture list -- only the prices may differ.
      expect(soft.fixtures.first.home.id, sharp.fixtures.first.home.id);
      for (var i = 0; i < soft.fixtures.length; i++) {
        expect(
          soft.fixtures[i].market.priceOf(Selection.home).decimal,
          isNot(
            closeTo(
              sharp.fixtures[i].market.priceOf(Selection.home).decimal,
              1e-6,
            ),
          ),
          reason: 'fixture $i should be priced differently',
        );
      }
    });

    test('on matchday 1 there is no hidden state to be blind to', () {
      // The flip side, pinned so the behaviour above is understood rather
      // than merely observed: with every club at a zeroed LatentState, the
      // blend has nothing to mix and awareness cannot move a price that
      // weather and referee do not also move.
      final soft = GameState(tuning: const Tuning(bookLatentAwareness: 0.1));
      final sharp = GameState(tuning: const Tuning(bookLatentAwareness: 1));
      addTearDown(soft.dispose);
      addTearDown(sharp.dispose);

      expect(
        soft.fixtures.first.market.priceOf(Selection.home).decimal,
        closeTo(
          sharp.fixtures.first.market.priceOf(Selection.home).decimal,
          1e-9,
        ),
      );
    });

    test('the margin knob reaches the quoted market', () {
      final fat = GameState(tuning: const Tuning(margin: 0.15));
      addTearDown(fat.dispose);

      expect(fat.fixtures.first.market.margin, closeTo(0.15, 1e-9));
    });

    test('a settled bet records ROI and CLV', () {
      final game = GameState();
      addTearDown(game.dispose);

      expect(game.performance.roi, isNull);

      game
        ..stake(0, Selection.home, 10)
        ..advanceDay();

      expect(game.performance.bets, 1);
      expect(game.performance.staked, 10);
      expect(game.performance.roi, isNotNull);
      expect(game.performance.averageClv, isNotNull);
      expect(game.history.first.closingLineValue, isNotNull);
    });
  });

  group('retuning restarts the season', () {
    testWidgets('a knob change rebuilds the game and clears the bankroll', (
      tester,
    ) async {
      // A taller viewport than the 800x600 default: the debug panel is an
      // extra ~180px of chrome, and on the default surface it pushes the
      // action bar out of the hit-testable area. Sizing the window is honest
      // here -- the panel only ever appears on a desktop debug build.
      tester.view
        ..physicalSize = const Size(1000, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeShell(showDebugTuning: true, store: MemorySaveStore()),
        ),
      );
      await tester.pump();

      // Win or lose, betting moves the bankroll off its starting value.
      await tester.tap(find.text('HOME').first);
      await tester.pump();
      await tester.tap(find.text('PLAY MATCHDAY'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // dismiss the results sheet
      await tester.pumpAndSettle();

      expect(find.text('matchday 2 of 38'), findsOneWidget);

      await tester.drag(find.byType(Slider).first, const Offset(-200, 0));
      await tester.pumpAndSettle();

      // Back to matchday 1 with a fresh bankroll: the season was regenerated
      // because every price it had quoted is now stale.
      expect(find.text('matchday 1 of 38'), findsOneWidget);
      expect(find.text('bankroll 1000.00'), findsOneWidget);
      expect(find.text('--'), findsNWidgets(3));
    });
  });
}
