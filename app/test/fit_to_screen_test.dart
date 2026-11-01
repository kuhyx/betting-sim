import 'package:betting_sim/state/save_store.dart';
import 'package:betting_sim/ui/friend_tile.dart';
import 'package:betting_sim/ui/home_shell.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pixel 6a geometry, physical px (see build-mobile-app R7): the status bar
/// is 132 px tall and the gesture area 63 px.
Future<void> _mount(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 2.625
    ..padding = const FakeViewPadding(top: 132, bottom: 63)
    ..viewPadding = const FakeViewPadding(top: 132, bottom: 63);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: HomeShell(showDebugTuning: false, store: MemorySaveStore()),
    ),
  );
  await tester.pump();
}

Future<void> _tab(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

/// Every vertical scrollable on the active tab must have nothing to scroll.
void _expectNoVerticalScroll(WidgetTester tester) {
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = tester.state<ScrollableState>(
      find.byElementPredicate((e) => e == element),
    );
    if (state.position.axis == Axis.vertical) {
      expect(
        state.position.maxScrollExtent,
        0,
        reason: 'a vertical Scrollable overflows the screen',
      );
    }
  }
}

/// [finder] is on screen, tappable, and clear of the navigation bar.
void _expectReachable(WidgetTester tester, Finder finder) {
  expect(
    finder.hitTestable(),
    findsWidgets,
    reason: '$finder not hit-testable',
  );
  final navTop = tester.getTopLeft(find.byType(NavigationBar)).dy;
  expect(tester.getRect(finder.first).bottom, lessThanOrEqualTo(navTop));
}

void main() {
  testWidgets('matchday fits one screen, with and without a stake', (
    tester,
  ) async {
    await _mount(tester);
    _expectNoVerticalScroll(tester);
    _expectReachable(tester, find.text('HOME').first);
    _expectReachable(tester, find.text('SKIP MATCHDAY'));

    await tester.tap(find.text('HOME').first);
    await tester.pump();
    _expectNoVerticalScroll(tester);
    _expectReachable(tester, find.text('PLAY MATCHDAY'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('friends fits one screen', (tester) async {
    await _mount(tester);
    await _tab(tester, Icons.people);
    _expectNoVerticalScroll(tester);
    _expectReachable(tester, find.byType(FriendTile).first);
    _expectReachable(tester, find.text('who owes who'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('life fits one screen, today and shop', (tester) async {
    await _mount(tester);
    await _tab(tester, Icons.home);
    _expectNoVerticalScroll(tester);
    _expectReachable(tester, find.text('GET THROUGH THE DAY'));
    _expectReachable(tester, find.byTooltip('an hour of work a shift'));

    await tester.tap(find.text('shop'));
    await tester.pumpAndSettle();
    _expectNoVerticalScroll(tester);
    _expectReachable(tester, find.text('a bicycle'));
    expect(tester.takeException(), isNull);
  });
}
