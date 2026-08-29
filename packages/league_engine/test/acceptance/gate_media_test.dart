import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

/// A season whose only interesting property is its ROI.
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
  group('gate 4a: the crowd is not an edge', () {
    test('passes when following the loudest voices loses', () {
      final result = gateTheCrowdIsNotAnEdge(_metrics('crowd', -0.04));
      expect(result.passed, isTrue);
      expect(result.detail, contains('-4.00%'));
    });

    test('fails when the consensus is free money', () {
      // The build this caught: with independent errors only, averaging the
      // panel cancelled the noise and the crowd returned +12.8%.
      expect(gateTheCrowdIsNotAnEdge(_metrics('crowd', 0.128)).passed, isFalse);
    });
  });

  group('gate 4b: the feed is worth reading', () {
    final oracle = _metrics('oracle', 0.20);
    final crowd = _metrics('crowd', -0.04);

    test('passes when the sharpest tipster beats the crowd and the vig', () {
      final result = gateTheFeedIsWorthReading(
        _metrics('insider', 0.07),
        crowd,
        oracle,
      );
      expect(result.passed, isTrue);
      expect(result.detail, contains('7.00%'));
      expect(result.toString(), startsWith('[PASS]'));
    });

    test('fails when nobody on the panel can beat the market', () {
      // Then keeping records is busywork and the feed is decoration.
      expect(
        gateTheFeedIsWorthReading(
          _metrics('insider', -0.01),
          crowd,
          oracle,
        ).passed,
        isFalse,
      );
    });

    test('fails when the best voice does no better than the crowd', () {
      expect(
        gateTheFeedIsWorthReading(
          _metrics('insider', 0.001),
          _metrics('crowd', 0.002),
          oracle,
        ).passed,
        isFalse,
      );
    });

    test('fails when reading one account rivals perfect knowledge', () {
      // A ceiling, not a target: if the feed approached what the truth is
      // worth, nobody would ever study a fixture list again.
      final result = gateTheFeedIsWorthReading(
        _metrics('insider', 0.18),
        crowd,
        oracle,
      );
      expect(result.passed, isFalse);
      expect(result.toString(), startsWith('[FAIL]'));
    });

    test('honours a different ceiling', () {
      expect(
        gateTheFeedIsWorthReading(
          _metrics('insider', 0.18),
          crowd,
          oracle,
          const MediaGateConfig(maxInsiderShare: 0.95),
        ).passed,
        isTrue,
      );
    });
  });
}
