import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('runAcceptance', () {
    // Small but real: enough seasons to exercise every path without turning a
    // unit test into the full gate run.
    final report = runAcceptance(seasons: 6, masterSeed: 4242);

    test('reports every strategy plus the perfect-book control', () {
      expect(
        report.strategies.map((s) => s.name),
        containsAll(<String>[
          'skilled',
          'random',
          'oracle',
          'random-vs-perfect',
        ]),
      );
    });

    test('runs all four gates', () {
      expect(report.gates, hasLength(4));
      expect(report.passed, report.gates.every((g) => g.passed));
    });

    test('is deterministic for a given seed', () {
      final again = runAcceptance(seasons: 6, masterSeed: 4242);
      expect(
        again.strategies.first.meanSeasonRoi,
        report.strategies.first.meanSeasonRoi,
      );
    });

    test('carries its parameters into the report', () {
      expect(report.seasons, 6);
      expect(report.masterSeed, 4242);
      expect(report.margin, 0.05);
    });

    test('honours a custom margin', () {
      final wide = runAcceptance(seasons: 3, masterSeed: 1, margin: 0.12);
      expect(wide.margin, 0.12);
      final random = wide.strategies.firstWhere((s) => s.name == 'random');
      expect(random.meanSeasonRoi, lessThan(0));
    });

    test('accepts an injected runner', () {
      final custom = runAcceptance(
        seasons: 3,
        masterSeed: 1,
        runner: const SeasonRunner(bookLatentAwareness: 1),
      );
      expect(custom.strategies, isNotEmpty);
    });
  });

  group('formatReport', () {
    test('prints every strategy, every gate and a verdict', () {
      final report = runAcceptance(seasons: 3, masterSeed: 77);
      final text = formatReport(report, const Duration(seconds: 2));

      expect(text, contains('betting-sim acceptance gate'));
      expect(text, contains('skilled'));
      expect(text, contains('random'));
      expect(text, contains('oracle'));
      expect(text, contains('gate 1'));
      expect(text, contains('gate 2'));
      expect(text, contains('gate 3a'));
      expect(text, contains('gate 3b'));
      expect(text, contains('wall: 2.0s'));
      expect(
        text,
        contains(report.passed ? 'ALL GATES PASSED' : 'GATES FAILED'),
      );
    });
  });
}
