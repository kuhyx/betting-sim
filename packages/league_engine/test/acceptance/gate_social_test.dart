import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

SeasonResult _season(double roi) => SeasonResult(
  matchdays: <MatchdayResult>[
    MatchdayResult(
      day: 0,
      bets: <SettledBet>[
        SettledBet(
          bet: const Bet(
            selection: Selection.home,
            stake: 100,
            taken: Odds(2),
          ),
          profit: roi * 100,
          closingLineValue: 0,
        ),
      ],
    ),
  ],
  bettorName: 'test',
);

StrategyMetrics _metrics(String name, double roi) =>
    summarise(name, <SeasonResult>[for (var i = 0; i < 30; i++) _season(roi)]);

void main() {
  group('gate 5a: friends charge less than the book', () {
    test('passes between the vig and zero', () {
      // No margin in a friend's price, so saying yes to everything should
      // cost less than the book -- but not nothing, because friends price off
      // the published line and inherit its blind spots.
      final result = gateFriendsAreCheaperThanTheBook(
        _metrics('accept-all', -0.024),
        0.05,
      );
      expect(result.passed, isTrue);
      expect(result.detail, contains('-2.40%'));
    });

    test('fails when taking every bet prints money', () {
      expect(
        gateFriendsAreCheaperThanTheBook(
          _metrics('accept-all', 0.03),
          0.05,
        ).passed,
        isFalse,
      );
    });

    test('fails when your mates are a worse bookmaker than the bookmaker', () {
      expect(
        gateFriendsAreCheaperThanTheBook(
          _metrics('accept-all', -0.09),
          0.05,
        ).passed,
        isFalse,
      );
    });
  });

  group('gate 5b: choosing beats accepting', () {
    final oracle = _metrics('oracle', 0.20);
    final acceptAll = _metrics('accept-all', -0.024);

    test('passes when picking your spots pays', () {
      final result = gateChoosingBeatsAccepting(
        _metrics('shrewd', 0.06),
        acceptAll,
        oracle,
      );
      expect(result.passed, isTrue);
      expect(result.detail, contains('6.00%'));
    });

    test('fails when choosing is not worth the trouble', () {
      expect(
        gateChoosingBeatsAccepting(
          _metrics('shrewd', -0.01),
          acceptAll,
          oracle,
        ).passed,
        isFalse,
      );
    });

    test('fails when choosing does no better than not choosing', () {
      expect(
        gateChoosingBeatsAccepting(
          _metrics('shrewd', 0.001),
          _metrics('accept-all', 0.002),
          oracle,
        ).passed,
        isFalse,
      );
    });

    test('fails when turning over your mates rivals perfect knowledge', () {
      // A cap, not a target: peer betting is a second table, not a way around
      // the bookmaker.
      expect(
        gateChoosingBeatsAccepting(
          _metrics('shrewd', 0.18),
          acceptAll,
          oracle,
        ).passed,
        isFalse,
      );
    });

    test('honours a different ceiling', () {
      expect(
        gateChoosingBeatsAccepting(
          _metrics('shrewd', 0.18),
          acceptAll,
          oracle,
          const SocialGateConfig(maxShrewdShare: 0.95),
        ).passed,
        isTrue,
      );
    });
  });
}
