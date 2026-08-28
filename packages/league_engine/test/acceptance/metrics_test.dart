import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

SettledBet _bet(double profit, {double stake = 10, double clv = 0}) {
  return SettledBet(
    bet: Bet(selection: Selection.home, stake: stake, taken: const Odds(2)),
    profit: profit,
    closingLineValue: clv,
  );
}

SeasonResult _season(List<List<SettledBet>> days) {
  return SeasonResult(
    matchdays: <MatchdayResult>[
      for (final (i, d) in days.indexed) MatchdayResult(day: i, bets: d),
    ],
    bettorName: 's',
  );
}

void main() {
  group('MatchdayResult', () {
    test('a day with no bet has a null ROI, not a zero one', () {
      // Counting a no-bet night as break-even would drag every statistic
      // toward zero and make gate 2 measure bet frequency instead of risk.
      const empty = MatchdayResult(day: 0, bets: []);
      expect(empty.roi, isNull);
      expect(empty.staked, 0);
      expect(empty.profit, 0);
    });

    test('sums stakes and profits', () {
      final day = MatchdayResult(day: 0, bets: [_bet(10), _bet(-10)]);
      expect(day.staked, 20);
      expect(day.profit, 0);
      expect(day.roi, 0);
    });
  });

  group('SeasonResult', () {
    test('counts only matchdays where a bet was struck as active', () {
      final season = _season([
        [_bet(10)],
        [],
        [_bet(-10)],
        [],
      ]);
      expect(season.activeMatchdays, hasLength(2));
      expect(season.betFrequency, 0.5);
    });

    test('an empty season does not divide by zero', () {
      const season = SeasonResult(matchdays: [], bettorName: 's');
      expect(season.betFrequency, 0);
      expect(season.roi, 0);
      expect(season.bets, isEmpty);
    });

    test('aggregates across matchdays', () {
      final season = _season([
        [_bet(10)],
        [_bet(-5)],
      ]);
      expect(season.staked, 20);
      expect(season.profit, 5);
      expect(season.roi, 0.25);
      expect(season.bets, hasLength(2));
    });
  });

  group('summarise', () {
    test('averages per-season ROI rather than pooling', () {
      // Kelly staking compounds, so a winning season stakes several times what
      // a losing one does; pooling would silently overweight the good ones.
      final metrics = summarise('s', [
        _season([
          [_bet(10)],
        ]),
        _season([
          [_bet(-100, stake: 1000)],
        ]),
      ]);
      // Pooled would be (10-100)/1010 = -8.9%. The mean of +100% and -10%
      // is +45%.
      expect(metrics.meanSeasonRoi, closeTo(0.45, 1e-9));
    });

    test('computes the median over active matchdays only', () {
      final metrics = summarise('s', [
        _season([
          [_bet(-2)],
          [],
          [],
          [_bet(-4)],
          [_bet(10)],
        ]),
      ]);
      expect(metrics.activeMatchdays, 3);
      expect(metrics.betFrequency, closeTo(0.6, 1e-9));
      expect(metrics.medianMatchdayRoi, closeTo(-0.2, 1e-9));
    });

    test('reports the losing-night fraction', () {
      final metrics = summarise('s', [
        _season([
          [_bet(-2)],
          [_bet(-2)],
          [_bet(5)],
          [_bet(5)],
        ]),
      ]);
      expect(metrics.losingNightFraction, 0.5);
    });

    test('summarises CLV and beat rate', () {
      final metrics = summarise('s', [
        _season([
          [_bet(1, clv: 0.02), _bet(1, clv: -0.01)],
        ]),
      ]);
      expect(metrics.meanClv, closeTo(0.005, 1e-9));
      expect(metrics.beatRate, 0.5);
    });

    test('handles a strategy that never bet', () {
      final metrics = summarise('s', [
        _season([[], []]),
      ]);
      expect(metrics.medianMatchdayRoi, 0);
      expect(metrics.losingNightFraction, 0);
      expect(metrics.meanClv, 0);
      expect(metrics.beatRate, 0);
      expect(metrics.standardError, 0);
    });

    test('the confidence interval widens with the standard error', () {
      final metrics = summarise('s', [
        _season([
          [_bet(10)],
        ]),
        _season([
          [_bet(-10)],
        ]),
        _season([
          [_bet(2)],
        ]),
      ]);
      final ci = metrics.confidenceInterval;
      expect(ci.low, lessThan(metrics.meanSeasonRoi));
      expect(ci.high, greaterThan(metrics.meanSeasonRoi));
    });
  });
}
