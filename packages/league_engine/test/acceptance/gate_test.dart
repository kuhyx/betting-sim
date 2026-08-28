import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

StrategyMetrics _metrics({
  String name = 's',
  double meanSeasonRoi = 0,
  double standardError = 0.001,
  double medianMatchdayRoi = 0,
  double losingNightFraction = 0.5,
}) {
  return StrategyMetrics(
    name: name,
    seasons: 100,
    meanSeasonRoi: meanSeasonRoi,
    standardError: standardError,
    medianMatchdayRoi: medianMatchdayRoi,
    losingNightFraction: losingNightFraction,
    activeMatchdays: 3800,
    betFrequency: 0.95,
    meanClv: 0.01,
    beatRate: 0.5,
  );
}

void main() {
  group('gate 1: skill pays over a season', () {
    test('passes only when the confidence interval excludes zero', () {
      expect(
        gateSkillPaysOverASeason(
          _metrics(meanSeasonRoi: 0.014, standardError: 0.003),
        ).passed,
        isTrue,
      );
    });

    test('a positive mean with a wide interval is not enough', () {
      // The difference between "won" and "won by luck". A strategy whose CI
      // straddles zero has not been shown to have an edge at all.
      expect(
        gateSkillPaysOverASeason(
          _metrics(meanSeasonRoi: 0.014, standardError: 0.02),
        ).passed,
        isFalse,
      );
    });

    test('a losing strategy fails', () {
      expect(
        gateSkillPaysOverASeason(_metrics(meanSeasonRoi: -0.02)).passed,
        isFalse,
      );
    });
  });

  group('gate 2: one night is a coin flip', () {
    test('passes on a negative median and a balanced losing fraction', () {
      expect(
        gateOneNightIsACoinFlip(
          _metrics(medianMatchdayRoi: -0.013, losingNightFraction: 0.506),
        ).passed,
        isTrue,
      );
    });

    test('fails when a single night is reliably profitable', () {
      // If the median night wins, the edge is visible nightly and the game has
      // no variance to survive -- the opposite of the intended feel.
      expect(
        gateOneNightIsACoinFlip(
          _metrics(medianMatchdayRoi: 0.02),
        ).passed,
        isFalse,
      );
    });

    test('fails when nights are too lopsided in either direction', () {
      expect(
        gateOneNightIsACoinFlip(_metrics(losingNightFraction: 0.30)).passed,
        isFalse,
      );
      expect(
        gateOneNightIsACoinFlip(_metrics(losingNightFraction: 0.70)).passed,
        isFalse,
      );
    });
  });

  group('gate 3a: the book charges exactly its margin', () {
    test('passes when a random bettor pays -v/(1+v)', () {
      expect(
        gateBookChargesItsMargin(_metrics(meanSeasonRoi: -0.0476), 0.05).passed,
        isTrue,
      );
    });

    test('fails when the book undercharges', () {
      expect(
        gateBookChargesItsMargin(_metrics(meanSeasonRoi: -0.01), 0.05).passed,
        isFalse,
      );
    });

    test('fails when the book overcharges', () {
      expect(
        gateBookChargesItsMargin(_metrics(meanSeasonRoi: -0.12), 0.05).passed,
        isFalse,
      );
    });

    test('tracks the margin it is given', () {
      for (final v in <double>[0.02, 0.05, 0.10]) {
        expect(
          gateBookChargesItsMargin(
            _metrics(meanSeasonRoi: -v / (1 + v)),
            v,
          ).passed,
          isTrue,
          reason: 'margin $v',
        );
      }
    });
  });

  group('gate 3b: chance loses, and skill beats chance', () {
    test('passes when chance loses and skill wins', () {
      expect(
        gateRandomBettorStillLoses(
          _metrics(name: 'random', meanSeasonRoi: -0.031),
          _metrics(name: 'skilled', meanSeasonRoi: 0.014),
        ).passed,
        isTrue,
      );
    });

    test('fails if a random bettor can profit', () {
      // The house edge has stopped existing; nothing else in the report means
      // anything.
      expect(
        gateRandomBettorStillLoses(
          _metrics(name: 'random', meanSeasonRoi: 0.01),
          _metrics(name: 'skilled', meanSeasonRoi: 0.05),
        ).passed,
        isFalse,
      );
    });

    test('fails if skill does no better than chance', () {
      expect(
        gateRandomBettorStillLoses(
          _metrics(name: 'random', meanSeasonRoi: -0.02),
          _metrics(name: 'skilled', meanSeasonRoi: -0.04),
        ).passed,
        isFalse,
      );
    });
  });

  group('GateResult', () {
    test('renders its verdict', () {
      const pass = GateResult(name: 'g', passed: true, detail: 'd');
      const fail = GateResult(name: 'g', passed: false, detail: 'd');
      expect(pass.toString(), '[PASS] g  d');
      expect(fail.toString(), '[FAIL] g  d');
    });
  });

  test('runGates reports every gate', () {
    final gates = runGates(
      skilled: _metrics(name: 'skilled', meanSeasonRoi: 0.014),
      random: _metrics(name: 'random', meanSeasonRoi: -0.03),
      randomVsPerfectBook: _metrics(meanSeasonRoi: -0.0476),
      margin: 0.05,
    );
    expect(gates, hasLength(4));
    expect(gates.every((g) => g.passed), isTrue);
  });
}
