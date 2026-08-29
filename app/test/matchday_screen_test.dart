import 'package:betting_sim/state/save_store.dart';
import 'package:betting_sim/ui/home_shell.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app as it SHIPS: the debug tuning panel hidden.
///
/// Explicitly false rather than defaulted, because the default is `kDebugMode`
/// and widget tests run in debug -- so leaving it implicit would test a
/// layout no player ever sees, and push the controls below off-screen. The
/// panel gets its own tests in debug_panel_test.dart.
///
/// Driven through `HomeShell` rather than `MatchdayScreen` directly: the
/// screen is a view over a game the shell owns, so mounting it alone would
/// test a composition that does not ship.
Widget _app() => MaterialApp(
  theme: buildTheme(),
  home: HomeShell(showDebugTuning: false, store: MemorySaveStore()),
);

/// Mounts the app and lets the save load resolve.
Future<void> _pumpApp(WidgetTester tester) async {
  // The navigation bar costs vertical room the 800x600 default does not have
  // once the action bar is also on screen.
  tester.view
    ..physicalSize = const Size(1000, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app());
  await tester.pump();
}

void main() {
  group('MatchdayScreen', () {
    testWidgets('shows the matchday, bankroll and a card of fixtures', (
      tester,
    ) async {
      await _pumpApp(tester);

      expect(find.text('matchday 1 of 38'), findsOneWidget);
      expect(find.text('bankroll 1000.00'), findsOneWidget);
      expect(find.text('HOME'), findsWidgets);
      expect(find.text('DRAW'), findsWidgets);
      expect(find.text('AWAY'), findsWidgets);
    });

    testWidgets('tapping a price stakes a bet', (tester) async {
      await _pumpApp(tester);

      expect(find.text('SKIP MATCHDAY'), findsOneWidget);

      await tester.tap(find.text('HOME').first);
      await tester.pump();

      // The action changes, the stake is shown, and the slip is visible.
      expect(find.text('PLAY MATCHDAY'), findsOneWidget);
      expect(find.text('staked 10'), findsOneWidget);
      expect(find.textContaining('to return'), findsOneWidget);
    });

    testWidgets('tapping the same price again clears the bet', (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.text('HOME').first);
      await tester.pump();
      expect(find.text('PLAY MATCHDAY'), findsOneWidget);

      await tester.tap(find.text('HOME').first);
      await tester.pump();
      expect(find.text('SKIP MATCHDAY'), findsOneWidget);
    });

    testWidgets('changing the stake size changes what is staked', (
      tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('50'));
      await tester.pump();
      await tester.tap(find.text('HOME').first);
      await tester.pump();

      expect(find.text('staked 50'), findsOneWidget);
    });

    testWidgets('the odds format toggle cycles through all three', (
      tester,
    ) async {
      await _pumpApp(tester);

      expect(find.text('decimal'), findsOneWidget);
      await tester.tap(find.text('decimal'));
      await tester.pump();
      expect(find.text('fractional'), findsOneWidget);

      await tester.tap(find.text('fractional'));
      await tester.pump();
      expect(find.text('american'), findsOneWidget);

      await tester.tap(find.text('american'));
      await tester.pump();
      expect(find.text('decimal'), findsOneWidget);
    });

    testWidgets('playing a matchday settles bets and shows the results', (
      tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('HOME').first);
      await tester.pump();
      await tester.tap(find.text('PLAY MATCHDAY'));
      await tester.pumpAndSettle();

      expect(find.text('results'), findsOneWidget);
      expect(find.textContaining('finished'), findsOneWidget);

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('matchday 2 of 38'), findsOneWidget);
    });

    testWidgets('skipping a matchday shows no results sheet', (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.text('SKIP MATCHDAY'));
      await tester.pumpAndSettle();

      expect(find.text('results'), findsNothing);
      expect(find.text('matchday 2 of 38'), findsOneWidget);
    });
  });
}
