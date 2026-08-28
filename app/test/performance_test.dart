import 'package:betting_sim/state/performance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Performance', () {
    test('an empty scoreboard reports null, not zero', () {
      final perf = Performance();

      // Null rather than zero throughout: no bets is not a break-even result,
      // and a 0.00% readout would read as "this setting is neutral" when it
      // means "no data yet" -- exactly the wrong signal while tuning.
      expect(perf.roi, isNull);
      expect(perf.averageClv, isNull);
      expect(perf.beatRate, isNull);
      expect(perf.bets, 0);
      expect(perf.staked, 0);
      expect(perf.profit, 0);
    });

    test('ROI pools profit over stake', () {
      final perf = Performance()
        ..record(stake: 10, profit: 5, clv: 0.01)
        ..record(stake: 30, profit: -10, clv: -0.02);

      expect(perf.bets, 2);
      expect(perf.staked, 40);
      expect(perf.profit, -5);
      expect(perf.roi, closeTo(-5 / 40, 1e-12));
    });

    test('CLV averages, and the beat rate counts strictly positive bets', () {
      final perf = Performance()
        ..record(stake: 10, profit: 0, clv: 0.04)
        ..record(stake: 10, profit: 0, clv: -0.02)
        ..record(stake: 10, profit: 0, clv: 0);

      expect(perf.averageClv, closeTo((0.04 - 0.02 + 0) / 3, 1e-12));
      // Zero CLV is not a beat: taking exactly the closing price is no edge.
      expect(perf.beatRate, closeTo(1 / 3, 1e-12));
    });

    test('a losing bet still counts toward stake', () {
      final perf = Performance()..record(stake: 25, profit: -25, clv: -0.05);

      expect(perf.staked, 25);
      expect(perf.roi, -1);
      expect(perf.beatRate, 0);
    });
  });
}
