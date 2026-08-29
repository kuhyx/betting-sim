import 'package:betting_sim/state/save.dart';
import 'package:betting_sim/state/save_store.dart';
import 'package:betting_sim/ui/home_shell.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(SaveStore store) => MaterialApp(
  theme: buildTheme(),
  home: HomeShell(showDebugTuning: false, store: store),
);

Future<void> _mount(WidgetTester tester, SaveStore store) async {
  tester.view
    ..physicalSize = const Size(1000, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(store));
  await tester.pump();
}

void main() {
  group('HomeShell', () {
    testWidgets('offers four destinations and switches between them', (
      tester,
    ) async {
      await _mount(tester, MemorySaveStore());

      expect(find.text('matchday 1 of 38'), findsOneWidget);
      for (final tab in <String>['feed', 'friends', 'life']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(find.text('not built yet'), findsOneWidget);
      }
      // The life tab reads the calendar the season is actually on.
      expect(find.textContaining('Sat wk1'), findsOneWidget);

      await tester.tap(find.text('matches'));
      await tester.pumpAndSettle();
      expect(find.text('matchday 1 of 38'), findsOneWidget);
    });

    testWidgets('writes a save once a matchday settles', (tester) async {
      final store = MemorySaveStore();
      await _mount(tester, store);

      expect(store.raw, isNull, reason: 'nothing has happened yet');

      await tester.tap(find.text('SKIP MATCHDAY'));
      await tester.pumpAndSettle();

      expect(SaveData.decode(store.raw)!.day, 1);
    });

    testWidgets('relaunching lands on the same day with the same money', (
      tester,
    ) async {
      final store = MemorySaveStore();
      await _mount(tester, store);

      await tester.tap(find.text('HOME').first);
      await tester.pump();
      await tester.tap(find.text('PLAY MATCHDAY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      final bankroll = tester
          .widgetList<Text>(find.textContaining('bankroll '))
          .first
          .data;
      expect(find.text('matchday 2 of 38'), findsOneWidget);

      // A cold start against the same storage: same day, same money.
      await tester.pumpWidget(const SizedBox.shrink());
      await _mount(tester, store);

      expect(find.text('matchday 2 of 38'), findsOneWidget);
      expect(find.text(bankroll!), findsOneWidget);
    });

    testWidgets('starts a new game when the save is unreadable', (
      tester,
    ) async {
      await _mount(tester, MemorySaveStore('{"version":1,"corrupt":true}'));

      expect(find.text('matchday 1 of 38'), findsOneWidget);
      expect(find.text('bankroll 1000.00'), findsOneWidget);
    });
  });
}
